# calculate_w_alphahull_national_lists.r

## Setup ------------------------
suppressMessages({
    library(sf)
    library(dplyr)
    library(rgbif)
    library(rangeBuilder)
})

## Source Scripts ------------------------
source("R/define_alphahull_helpers.r")

## Define Taxon Queue ------------------------
taxon_queue <- c("Fungi", "Amphibians", "Mollusks", "Corals", "Sharks & Rays", "Mammals", "Insects", "Reptiles", "Birds", "Fish", "Plants")

## Set Run Mode ------------------------
if (!exists("use_cached_coords")) use_cached_coords <- FALSE

## Loop Checkpointed Batch Runs ------------------------
out_dir <- "outputs/national_lists/by_group_alpha"
coord_dir <- "outputs/national_lists/raw_coordinates"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
if (!dir.exists(coord_dir)) dir.create(coord_dir, recursive = TRUE)
batch_size <- 20
for (run_taxon in taxon_queue) {
    slug <- gsub("[^a-z0-9]+", "_", tolower(run_taxon))
    final_csv_path <- file.path(out_dir, paste0(slug, ".csv"))
    if (file.exists(final_csv_path)) {
        message(paste0("\n", run_taxon, ": already completed (", final_csv_path, " exists) - skipping.\n"))
        next
    }

    message(paste0("\n\n########## ", run_taxon, " ##########\n"))
    candidates <- build_candidates(run_taxon)
    message(paste0(run_taxon, ": ", nrow(candidates), " IUCN-rated candidates (all categories, including LC)."))
    print(table(candidates$red_list_category_code, useNA = "ifany"))

    cache_path <- file.path(out_dir, paste0(slug, "_cache.rds"))
    already_done <- if (file.exists(cache_path)) readRDS(cache_path) else NULL
    remaining <- if (!is.null(already_done)) candidates %>% filter(!(gbif_id %in% already_done$gbif_id)) else candidates
    message(paste0(nrow(candidates) - nrow(remaining), " already checkpointed, ", nrow(remaining), " remaining."))

    coord_cache_path <- file.path(coord_dir, paste0(slug, ".rds"))
    coord_cache <- if (file.exists(coord_cache_path)) readRDS(coord_cache_path) else list()

    if (nrow(remaining) > 0) {
        batch_ix <- split(seq_len(nrow(remaining)), ceiling(seq_len(nrow(remaining)) / batch_size))
        for (b in seq_along(batch_ix)) {
            batch <- remaining[batch_ix[[b]], ]
            message(paste0("\n=== ", run_taxon, " batch ", b, "/", length(batch_ix), " (", nrow(batch), " species) ===\n"))
            batch_runs <- lapply(seq_len(nrow(batch)), function(i) {
                message(paste0("  [", i, "/", nrow(batch), "] ", batch$species[i], " (clip=", batch$clip[i], ")..."))
                r <- run_alpha_hull(batch$gbif_id[i], batch$species[i], batch$clip[i],
                    cached_coords = coord_cache[[as.character(batch$gbif_id[i])]], use_cached_coords = use_cached_coords, return_coords = TRUE)
                r$summary$clip <- batch$clip[i]
                r$summary$category <- batch$red_list_category_code[i]
                message(paste0("    -> weight=", ifelse(is.na(r$summary$weight), "NA", round(r$summary$weight * 100, 4)), "% ",
                    ifelse(is.na(r$summary$note), "", paste0("(", r$summary$note, ")"))))
                r
            })
            batch_result <- bind_rows(lapply(batch_runs, `[[`, "summary"))
            new_coords <- setNames(lapply(batch_runs, `[[`, "coords"), as.character(batch$gbif_id))
            new_coords <- new_coords[!sapply(new_coords, is.null)]
            coord_cache[names(new_coords)] <- new_coords
            already_done <- bind_rows(already_done, batch_result)
            saveRDS(already_done, cache_path)
            saveRDS(coord_cache, coord_cache_path)
            message(paste0("  Checkpointed - ", nrow(already_done), " species saved."))
        }
    }

    out <- already_done %>%
        mutate(range_share_pct = if_else(!is.na(weight), paste0(sprintf("%.2f", round(weight * 100, 2)), "%"), NA_character_)) %>%
        arrange(desc(weight))
    write.csv(out, final_csv_path, row.names = FALSE, na = "")
    message(paste0(
        "\n", nrow(out), " species processed for ", run_taxon, ". ", sum(!is.na(out$weight)), " got a computed weight. ",
        sum(!is.na(out$weight) & out$weight >= 0.20), " at >=20% range share.\n",
        "Saved to ", final_csv_path
    ))
}
message("\n\n=== All taxa in queue complete ===")
