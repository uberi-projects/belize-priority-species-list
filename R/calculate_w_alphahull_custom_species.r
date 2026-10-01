# calculate_w_alphahull_custom_species.r

## Setup ------------------------
suppressMessages({
    library(sf)
    library(dplyr)
    library(rgbif)
    library(rangeBuilder)
    library(rredlist)
})

## Source Scripts ------------------------
source("R/build_belize_boundary.r")
source("R/define_alphahull_helpers.r")

## Set Run Mode ------------------------
if (!exists("use_cached_coords")) use_cached_coords <- FALSE
if (!exists("request_citation_doi")) request_citation_doi <- TRUE

## Define Custom Species List ------------------------
# Edit this to the species you want to check. `clip` is required for every species -
# "no" (no clipping), "terrestrial" (clips out oceans), or "aquatic" (clips out land).
custom_species <- data.frame(
    species = c("Panthera onca"),
    clip = c("no"),
    stringsAsFactors = FALSE
)

## Resolve Taxon Keys ------------------------
custom_species$gbif_id <- sapply(custom_species$species, function(nm) {
    bb <- name_backbone(name = nm)
    if (is.null(bb$usageKey)) NA_character_ else as.character(bb$usageKey)
})
unresolved <- custom_species$species[is.na(custom_species$gbif_id)]
if (length(unresolved) > 0) {
    warning(paste0("Could not resolve a GBIF taxon key for: ", paste(unresolved, collapse = ", ")))
}
custom_species <- custom_species %>% filter(!is.na(gbif_id))

## Look Up Global IUCN Status ------------------------
custom_species$iucn_category <- sapply(custom_species$species, function(nm) {
    parts <- strsplit(nm, " ", fixed = TRUE)[[1]]
    if (length(parts) < 2) return(NA_character_)
    res <- tryCatch(
        rl_species_latest(genus = parts[1], species = paste(parts[-1], collapse = " "), key = Sys.getenv("IUCN_REDLIST_KEY")),
        error = function(e) NULL
    )
    if (is.null(res) || is.null(res$red_list_category) || is.null(res$red_list_category$code)) return(NA_character_)
    res$red_list_category$code
})

## Look Up National Belize Status ------------------------
national_raw <- read.csv("data/national_priority_lists/Belize_Threatened_Species_Table.csv", stringsAsFactors = FALSE)
is_tree_source <- grepl("^Trees Workshop Report", national_raw$Source)
has_parens <- grepl("\\(.*\\)$", national_raw$Species)
inside_parens <- trimws(sub(".*\\(([^)]+)\\)$", "\\1", national_raw$Species))
outside_parens <- trimws(sub("\\s*\\([^)]+\\)$", "", national_raw$Species))
national_raw$scientific_name <- ifelse(is_tree_source, outside_parens, ifelse(has_parens, inside_parens, outside_parens))
national_lookup <- national_raw %>%
    group_by(scientific_name) %>%
    summarise(belize_ranking = paste(unique(Ranking), collapse = " / "), .groups = "drop")
custom_species <- custom_species %>% left_join(national_lookup, by = c("species" = "scientific_name"))

## Select Remaining Species ------------------------
if (!dir.exists("outputs/results/custom")) dir.create("outputs/results/custom", recursive = TRUE)
out_path <- "outputs/results/custom/custom_species_results.csv"
already_done <- if (file.exists(out_path)) read.csv(out_path, colClasses = c(gbif_id = "character")) else NULL
remaining <- if (!is.null(already_done)) custom_species %>% filter(!(gbif_id %in% already_done$gbif_id)) else custom_species
message(paste0(nrow(custom_species) - nrow(remaining), " already computed, ", nrow(remaining), " remaining."))

## Compute Range Shares ------------------------
coord_dir <- "outputs/intermediates/primary/raw_coordinates"
if (!dir.exists(coord_dir)) dir.create(coord_dir, recursive = TRUE)
coord_cache_path <- file.path(coord_dir, "custom_species.rds")
coord_cache <- if (file.exists(coord_cache_path)) readRDS(coord_cache_path) else list()
if (nrow(remaining) > 0) {
    batch_runs <- lapply(seq_len(nrow(remaining)), function(i) {
        message(paste0("[", i, "/", nrow(remaining), "] ", remaining$species[i], " (clip=", remaining$clip[i], ")..."))
        r <- run_alpha_hull(remaining$gbif_id[i], remaining$species[i], remaining$clip[i],
            cached_coords = coord_cache[[as.character(remaining$gbif_id[i])]], use_cached_coords = use_cached_coords, return_coords = TRUE)
        r$summary$clip <- remaining$clip[i]
        r$summary$iucn_category <- remaining$iucn_category[i]
        r$summary$belize_ranking <- remaining$belize_ranking[i]
        message(paste0("  -> weight=", ifelse(is.na(r$summary$weight), "NA", round(r$summary$weight * 100, 4)), "% ",
            ifelse(is.na(r$summary$note), "", paste0("(", r$summary$note, ")"))))
        r
    })
    new_results <- bind_rows(lapply(batch_runs, `[[`, "summary"))
    new_coords <- setNames(lapply(batch_runs, `[[`, "coords"), as.character(remaining$gbif_id))
    new_coords <- new_coords[!sapply(new_coords, is.null)]
    coord_cache[names(new_coords)] <- new_coords
    saveRDS(coord_cache, coord_cache_path)
    already_done <- bind_rows(already_done, new_results)
}

## Export Results ------------------------
write.csv(already_done, out_path, row.names = FALSE, na = "")
message(paste0("\n", nrow(already_done), " species -> ", out_path))

## Submit Citation Download (optional) ------------------------
if (request_citation_doi) {
    download_key <- occ_download(
        pred_in("taxonKey", unique(already_done$gbif_id)),
        pred("hasCoordinate", TRUE),
        pred("hasGeospatialIssue", FALSE),
        format = "SIMPLE_CSV",
        user = Sys.getenv("GBIF_USER"),
        pwd = Sys.getenv("GBIF_PWD"),
        email = Sys.getenv("GBIF_EMAIL")
    )
    message(paste0("Citation download submitted. Key: ", download_key))
    if (!dir.exists("outputs/results/citation")) dir.create("outputs/results/citation", recursive = TRUE)
    saveRDS(as.character(download_key), "outputs/results/citation/custom_species_citation_download_key.rds")
    terminal_statuses <- c("SUCCEEDED", "KILLED", "FAILED", "CANCELLED")
    repeat {
        status <- occ_download_meta(download_key)$status
        message(paste0("  Status: ", status))
        if (status %in% terminal_statuses) break
        Sys.sleep(90)
    }
    message(paste0(
        "Download finished with status: ", status,
        ". DOI/details at https://www.gbif.org/occurrence/download/", download_key
    ))
}
