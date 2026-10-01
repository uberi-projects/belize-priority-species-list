# run_pipeline.r

## Setup ------------------------
source("R/load_packages.r")

## Configure Run ------------------------
use_cached_coords <- FALSE
run_extended_list <- FALSE
run_citation_download <- FALSE

## Build Candidate Pool ------------------------
source("R/load_redlist.r")
source("R/load_national_lists.r")

## Build Belize Boundary ------------------------
source("R/spatial_weight_functions.r")

## Compute Alpha-Hull Range Shares ------------------------
source("R/calculate_w_alphahull_national_lists.r")

## Retry Transient GBIF Fetch Failures ------------------------
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
fetch_failed <- bind_rows(lapply(groups, function(g) {
    read.csv(file.path("outputs/national_lists/by_group_alpha", paste0(g, ".csv")), colClasses = c(gbif_id = "character")) %>%
        filter(note == "GBIF fetch failed after retries") %>%
        transmute(gbif_id, species, clip, taxon = g)
}))
if (nrow(fetch_failed) > 0) {
    message(paste0(nrow(fetch_failed), " species hit a transient GBIF fetch failure - retrying..."))
    saveRDS(fetch_failed, "outputs/national_lists/by_group_alpha/fetch_failed_for_retry.rds")
    system2("Rscript", c("R/retry_gbif_fetch_failures.r", "1", "1"))
    source("R/merge_fetch_retry_results.r")
} else {
    message("No transient GBIF fetch failures to retry.")
}

## Compute BirdLife Comparison Weights ------------------------
if (file.exists("birdlife_ranges/BOTW_2025.gpkg")) {
    source("R/calculate_w_birdlife.r")
} else {
    message("birdlife_ranges/BOTW_2025.gpkg not found - skipping BirdLife comparison weights.")
}

## Export Final Deliverable ------------------------
source("R/export_alpha_results_by_group.r")

## Run Extended-List Discovery Pipeline ------------------------
if (run_extended_list) {
    source("R/check_gbif_checklist_gaps.r")
    source("R/screen_gbif_checklist_gaps.r")
    source("R/retry_gbif_checklist_screen.r")
    source("R/calculate_w_alphahull_checklist_gaps.r")
    source("R/export_alpha_extended_by_group.r")
}

## Submit Citation Download ------------------------
if (run_citation_download) {
    source("R/build_citation_taxon_keys.r")
    source("R/submit_gbif_citation_download.r")
}

message("\n=== Pipeline complete ===")
