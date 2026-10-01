# export_alpha_results_by_group.r

## Setup ------------------------
suppressMessages({
    library(dplyr)
    library(rgbif)
})

## Load National Lists ------------------------
nlr <- readRDS("outputs/intermediates/national_lists/national_lists_resolved.rds") %>%
    select(species, common_name, belize_ranking = national_2025) %>%
    distinct(species, .keep_all = TRUE)

## Check BirdLife Availability ------------------------
birdlife_path <- "outputs/intermediates/primary/weights_belize_birdlife.rds"
birdlife <- if (file.exists(birdlife_path)) {
    readRDS(birdlife_path) %>%
        select(species, weight_birdlife) %>%
        distinct(species, .keep_all = TRUE)
} else {
    message("BirdLife weights not found (", birdlife_path, ") - BirdLife columns will show 'No Map Available'. ",
        "Run R/calculate_w_birdlife.r first if you have birdlife_ranges/BOTW_2025.gpkg.")
    data.frame(species = character(), weight_birdlife = numeric(), stringsAsFactors = FALSE)
}

## Define Severity Scale ------------------------
# Watchlist folded into the same severity tier as NT for this file.
severity_rank <- function(x) {
    case_when(
        x == "CR" ~ 1,
        x == "EN" ~ 2,
        x == "VU" ~ 3,
        x %in% c("NT", "LR/nt", "Watch List (NT/LC/DD)", "NT/LC") ~ 4,
        x == "LC" ~ 6,
        TRUE ~ 7
    )
}

## Define Common-Name Lookup ------------------------
name_cache_path <- "outputs/intermediates/primary/vernacular_names_cache.rds"
name_cache <- if (file.exists(name_cache_path)) readRDS(name_cache_path) else data.frame(gbif_id = character(), common_name = character(), stringsAsFactors = FALSE)
lookup_common_name <- function(gbif_id) {
    res <- tryCatch(rgbif::name_usage(key = as.numeric(gbif_id), data = "vernacularNames"), error = function(e) NULL)
    if (is.null(res) || is.null(res$data) || nrow(res$data) == 0) return(NA_character_)
    eng <- res$data[tolower(res$data$language) %in% c("eng", "en"), ]
    if (nrow(eng) == 0) return(NA_character_)
    eng$vernacularName[1]
}

## Define Taxonomic Groups ------------------------
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
group_labels <- c(
    reptiles = "Reptiles", fungi = "Fungi", amphibians = "Amphibians", mollusks = "Mollusks",
    corals = "Corals", sharks_rays = "Sharks & Rays", mammals = "Mammals", insects = "Insects",
    birds = "Birds", fish = "Fish", plants = "Plants"
)
out_dir <- "outputs/results/primary/by_group_filtered"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

## Build And Export Per-Group CSVs ------------------------
for (g in groups) {
    src_path <- file.path("outputs/results/primary/by_group_all", paste0(g, ".csv"))
    d <- read.csv(src_path, stringsAsFactors = FALSE, colClasses = c(gbif_id = "character"))
    d <- d %>%
        left_join(nlr, by = "species") %>%
        { if (g == "birds") left_join(., birdlife, by = "species") else mutate(., weight_birdlife = NA_real_) } %>%
        mutate(worst_rank = pmin(severity_rank(category), severity_rank(belize_ranking), na.rm = TRUE)) %>%
        filter(worst_rank <= 4 | (!is.na(weight) & weight >= 0.20))
    # Fresh lookup for qualifying species still missing a common name
    need_lookup <- d %>% filter(is.na(common_name), !(gbif_id %in% name_cache$gbif_id)) %>% pull(gbif_id) %>% unique()
    if (length(need_lookup) > 0) {
        message(paste0(g, ": looking up common names for ", length(need_lookup), " species..."))
        new_names <- bind_rows(lapply(need_lookup, function(id) {
            data.frame(gbif_id = id, common_name = lookup_common_name(id), stringsAsFactors = FALSE)
        }))
        name_cache <- bind_rows(name_cache, new_names) %>% distinct(gbif_id, .keep_all = TRUE)
        saveRDS(name_cache, name_cache_path)
    }
    d <- d %>%
        left_join(name_cache %>% rename(common_name_fresh = common_name), by = "gbif_id") %>%
        mutate(common_name = coalesce(common_name, common_name_fresh))
    # Normalize capitalization 
    d <- d %>% mutate(common_name = ifelse(is.na(common_name), NA_character_, tools::toTitleCase(common_name)))
    # Use Sort key: BirdLife-preferred for birds, alpha-hull for everyone else 
    d <- d %>%
        mutate(sort_weight = if (g == "birds") coalesce(weight_birdlife, weight) else weight) %>%
        arrange(worst_rank, desc(sort_weight))

    out <- d %>%
        transmute(
            `Common Name` = common_name,
            `Scientific Name` = species,
            `IUCN Ranking` = category,
            `Belize Ranking 2025` = belize_ranking,
            `Range Share` = case_when(
                !is.na(weight) ~ paste0(sprintf("%.2f", round(weight * 100, 2)), "%"),
                grepl("^getDynamicAlphaHull failed|hull geometry invalid/empty", note) ~ "Invalid Geometry",
                TRUE ~ "Data Deficient"
            ),
            `Range Share (BirdLife)` = if (g == "birds") if_else(!is.na(weight_birdlife), paste0(sprintf("%.2f", round(weight_birdlife * 100, 2)), "%"), "No Map Available") else NA_character_,
            Responsibility = if_else(!is.na(weight), strrep("~", floor(weight * 100 / 20)), NA_character_),
            `Responsibility (BirdLife)` = if (g == "birds") if_else(!is.na(weight_birdlife), strrep("~", floor(weight_birdlife * 100 / 20)), NA_character_) else NA_character_,
            Sample = n_points
        )
    if (g != "birds") out <- out %>% select(-`Range Share (BirdLife)`, -`Responsibility (BirdLife)`)
    out_path <- file.path(out_dir, paste0("priority_species_", g, ".csv"))
    write.csv(out, out_path, row.names = FALSE, na = "")
    message(paste0(group_labels[g], ": ", nrow(out), " species -> ", out_path))
}
message("\nDone.")
