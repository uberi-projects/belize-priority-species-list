# calculate_w_alphahull_checklist_gaps.r

## Setup ------------------------
suppressMessages({
    library(sf)
    library(dplyr)
    library(rgbif)
    library(rangeBuilder)
})

## Source Scripts ------------------------
source("R/define_alphahull_helpers.r")

## Set Run Mode ------------------------
if (!exists("use_cached_coords")) use_cached_coords <- FALSE

## Select Candidates ------------------------
screened <- readRDS("outputs/intermediates/extended/gbif_checklist_screen_results.rds")
candidates <- screened %>% filter(clears_gate)
message(paste0(nrow(candidates), " species clear the screen and need a range-share computation."))

## Select Remaining Species ------------------------
weights_cache_path <- "outputs/intermediates/extended/gbif_checklist_gap_weights_alpha.rds"
already_done <- if (file.exists(weights_cache_path)) readRDS(weights_cache_path) else NULL
remaining <- if (!is.null(already_done)) candidates %>% filter(!(gbif_id %in% already_done$gbif_id)) else candidates
message(paste0(nrow(candidates) - nrow(remaining), " already checkpointed, ", nrow(remaining), " remaining."))

## Compute Range Shares By Taxon ------------------------
coord_dir <- "outputs/intermediates/primary/raw_coordinates"
if (!dir.exists(coord_dir)) dir.create(coord_dir, recursive = TRUE)
batch_size <- 50
for (run_taxon in unique(remaining$taxon)) {
    taxon_remaining <- remaining %>% filter(taxon == run_taxon)
    clip <- clip_map[[run_taxon]]
    slug <- gsub("[^a-z0-9]+", "_", tolower(run_taxon))
    coord_cache_path <- file.path(coord_dir, paste0(slug, ".rds"))
    coord_cache <- if (file.exists(coord_cache_path)) readRDS(coord_cache_path) else list()

    message(paste0("\n\n########## ", run_taxon, " (", nrow(taxon_remaining), " gap candidates) ##########\n"))
    batch_ix <- split(seq_len(nrow(taxon_remaining)), ceiling(seq_len(nrow(taxon_remaining)) / batch_size))
    for (b in seq_along(batch_ix)) {
        batch <- taxon_remaining[batch_ix[[b]], ]
        message(paste0("\n=== ", run_taxon, " batch ", b, "/", length(batch_ix), " (", nrow(batch), " species) ===\n"))
        batch_runs <- lapply(seq_len(nrow(batch)), function(i) {
            message(paste0("  [", i, "/", nrow(batch), "] ", batch$species[i], "..."))
            r <- run_alpha_hull(batch$gbif_id[i], batch$species[i], clip,
                cached_coords = coord_cache[[as.character(batch$gbif_id[i])]], use_cached_coords = use_cached_coords, return_coords = TRUE)
            r$summary$taxon <- batch$taxon[i]
            message(paste0("    -> weight=", ifelse(is.na(r$summary$weight), "NA", round(r$summary$weight * 100, 4)), "% ",
                ifelse(is.na(r$summary$note), "", paste0("(", r$summary$note, ")"))))
            r
        })
        batch_result <- bind_rows(lapply(batch_runs, `[[`, "summary"))
        new_coords <- setNames(lapply(batch_runs, `[[`, "coords"), as.character(batch$gbif_id))
        new_coords <- new_coords[!sapply(new_coords, is.null)]
        coord_cache[names(new_coords)] <- new_coords
        already_done <- bind_rows(already_done, batch_result)
        saveRDS(already_done, weights_cache_path)
        saveRDS(coord_cache, coord_cache_path)
        message(paste0("  Checkpointed - ", nrow(already_done), " species saved."))
    }
}

## Report Summary ------------------------
n_at_20 <- sum(!is.na(already_done$weight) & already_done$weight >= 0.20)
message(paste0(
    "\n", nrow(already_done), " species computed. ",
    sum(!is.na(already_done$weight)), " got a real weight. ",
    n_at_20, " are at >=20% Belize range (genuine new criterion-3 discoveries)."
))
