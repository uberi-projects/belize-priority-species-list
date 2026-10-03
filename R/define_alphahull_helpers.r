# define_alphahull_helpers.r

## Define Taxon And Clip Maps ------------------------
taxon_class_map <- list(
    Amphibians = c("Amphibia"),
    Birds = c("Aves"),
    Corals = c("Anthozoa", "Hydrozoa"),
    Fungi = c("Agaricomycetes", "Jungermanniopsida"),
    Insects = c("Insecta"),
    Mammals = c("Mammalia"),
    Mollusks = c("Gastropoda", "Bivalvia", "Cephalopoda", "Polyplacophora", "Scaphopoda"),
    Plants = c("Magnoliopsida", "Liliopsida", "Cycadopsida", "Pinopsida"),
    Reptiles = c("Squamata", "Testudines", "Crocodylia"),
    `Sharks & Rays` = c("Elasmobranchii", "Holocephali")
)
clip_map <- list(
    Amphibians = "terrestrial", Fungi = "terrestrial", Insects = "terrestrial",
    Corals = "aquatic", `Sharks & Rays` = "aquatic",
    Birds = "no", Mammals = "no", Mollusks = "no", Plants = "no", Reptiles = "no"
)

## Build Candidate Pool ------------------------
# Fish use FishBase's Freshwater/Brackish/Saltwater flags for per-species clip
build_candidates <- function(run_taxon) {
    if (run_taxon == "Fish") {
        fb <- readRDS("outputs/intermediates/fishbase/fb_belize_species.rds")
        candidates <- belize_redlist_taxa %>%
            filter(gbif_id %in% as.character(fb$speciesKey) | species %in% fb$species) %>%
            filter(!is.na(gbif_id))
        fb_join <- fb %>% distinct(species, .keep_all = TRUE) %>% select(species, Freshwater, Brackish, Saltwater)
        candidates <- candidates %>%
            left_join(fb_join, by = "species") %>%
            mutate(clip = case_when(
                Freshwater & !Saltwater ~ "terrestrial",
                Saltwater & !Freshwater ~ "aquatic",
                TRUE ~ "no"
            ))
    } else {
        classes <- taxon_class_map[[run_taxon]]
        candidates <- belize_redlist_taxa %>%
            filter(class %in% classes, !is.na(gbif_id)) %>%
            mutate(clip = clip_map[[run_taxon]])
    }
    candidates
}

## Fetch GBIF Coordinates ------------------------
fetch_gbif_coords <- function(gbif_id, max_retries = 3, retry_wait_sec = 5) {
    fetch <- NULL
    for (attempt in seq_len(max_retries)) {
        fetch <- try(occ_data(taxonKey = gbif_id, hasCoordinate = TRUE, hasGeospatialIssue = FALSE, limit = 5000), silent = TRUE)
        if (!inherits(fetch, "try-error") && !is.null(fetch$data)) break
        if (attempt < max_retries) Sys.sleep(retry_wait_sec)
    }
    if (inherits(fetch, "try-error") || is.null(fetch$data)) return(NULL)
    fetch$data %>%
        select(decimalLongitude, decimalLatitude) %>%
        filter(!is.na(decimalLongitude), !is.na(decimalLatitude)) %>%
        distinct()
}

## Define Alpha-Hull Wrapper ------------------------
# No in-process timeout guard: setTimeLimit()/callr(timeout=)/system2(timeout=) all crash this R
# session outright when they fire, worse than an occasional slow species. A stall is rare and
# handled manually (stop/resume - cleanly picks up from the last checkpoint).
run_alpha_hull <- function(gbif_id, species_name, clip, cached_coords = NULL, use_cached_coords = FALSE,
    return_coords = FALSE, max_retries = 3, retry_wait_sec = 5) {
    # List, not an attribute on the data.frame - bind_rows() doesn't reliably keep per-row attrs.
    wrap <- function(out, coords = NULL) if (return_coords) list(summary = out, coords = coords) else out

    if (use_cached_coords && !is.null(cached_coords)) {
        coords <- cached_coords
    } else {
        coords <- fetch_gbif_coords(gbif_id, max_retries, retry_wait_sec)
        if (is.null(coords)) {
            return(wrap(data.frame(gbif_id = gbif_id, species = species_name, n_points = NA, alpha = NA_character_,
                n_parts = NA, global_area_km2 = NA, belize_area_km2 = NA, weight = NA, note = "GBIF fetch failed after retries")))
        }
    }
    if (nrow(coords) < 3) {
        return(wrap(data.frame(gbif_id = gbif_id, species = species_name, n_points = nrow(coords), alpha = NA_character_,
            n_parts = NA, global_area_km2 = NA, belize_area_km2 = NA, weight = NA, note = "fewer than 3 unique coordinate points"), coords))
    }
    result <- try(getDynamicAlphaHull(coords, coordHeaders = c("decimalLongitude", "decimalLatitude"), clipToCoast = clip, verbose = FALSE), silent = TRUE)
    if (inherits(result, "try-error")) {
        return(wrap(data.frame(gbif_id = gbif_id, species = species_name, n_points = nrow(coords), alpha = NA_character_,
            n_parts = NA, global_area_km2 = NA, belize_area_km2 = NA, weight = NA, note = paste("getDynamicAlphaHull failed:", as.character(result))), coords))
    }
    hull <- try(st_make_valid(result[[1]]), silent = TRUE)
    if (inherits(hull, "try-error") || length(hull) == 0 || any(st_is_empty(hull))) {
        return(wrap(data.frame(gbif_id = gbif_id, species = species_name, n_points = nrow(coords), alpha = as.character(result$alpha),
            n_parts = NA, global_area_km2 = NA, belize_area_km2 = NA, weight = NA, note = "hull geometry invalid/empty after clip"), coords))
    }
    global_area_km2 <- sum(as.numeric(st_area(st_transform(hull, mollweide_crs)))) / 1e6
    belize_int <- try(st_intersection(hull, belize_boundary), silent = TRUE)
    belize_area_km2 <- if (inherits(belize_int, "try-error") || length(belize_int) == 0) 0 else sum(as.numeric(st_area(st_transform(belize_int, mollweide_crs)))) / 1e6
    wrap(data.frame(
        gbif_id = gbif_id, species = species_name, n_points = nrow(coords), alpha = as.character(result$alpha),
        n_parts = length(hull), global_area_km2 = round(global_area_km2, 1), belize_area_km2 = round(belize_area_km2, 1),
        weight = if (global_area_km2 > 0) belize_area_km2 / global_area_km2 else NA, note = NA_character_
    ), coords)
}
