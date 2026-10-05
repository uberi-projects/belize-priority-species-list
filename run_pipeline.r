# run_pipeline.r

## Setup ------------------------
source("R/load_packages.r")

## Configure Run ------------------------
use_cached_coords <- FALSE
run_extended_list <- FALSE
run_citation_download <- TRUE

## Build Candidate Pool ------------------------
source("R/load_redlist.r")
source("R/load_national_lists.r")

## Build Belize Boundary ------------------------
source("R/build_belize_boundary.r")

## Compute Alpha-Hull Range Shares ------------------------
source("R/calculate_w_alphahull_national_lists.r")

## Retry Transient GBIF Fetch Failures ------------------------
source("R/retry_gbif_fetch_failures_loop.r")

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
