# calculate_w_alphahull_parallel_worker.r

## Setup ------------------------
suppressMessages({
    library(sf)
    library(dplyr)
    library(rgbif)
    library(rangeBuilder)
})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) stop("Usage: Rscript calculate_w_alphahull_parallel_worker.r <taxon> <partition_id> <n_partitions>")
run_taxon <- args[1]
partition_id <- as.integer(args[2])
n_partitions <- as.integer(args[3])

## Source Scripts ------------------------
source("R/load_packages.r")
source("R/load_redlist.r")
source("R/spatial_weight_functions.r")
source("R/alphahull_helpers.r")

## Build Candidate Pool ------------------------
out_dir <- "outputs/national_lists/by_group_alpha"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
slug <- gsub("[^a-z0-9]+", "_", tolower(run_taxon))
batch_size <- 20
message(paste0("Worker ", partition_id, "/", n_partitions, " for ", run_taxon, " starting..."))
candidates <- build_candidates(run_taxon)
message(paste0(run_taxon, ": ", nrow(candidates), " total IUCN-rated candidates."))

## Exclude Completed Species ------------------------
main_cache_path <- file.path(out_dir, paste0(slug, "_cache.rds"))
already_done_ids <- character()
if (file.exists(main_cache_path)) already_done_ids <- c(already_done_ids, readRDS(main_cache_path)$gbif_id)
existing_parts <- list.files(out_dir, pattern = paste0("^", slug, "_cache_part[0-9]+\\.rds$"), full.names = TRUE)
for (p in existing_parts) already_done_ids <- c(already_done_ids, readRDS(p)$gbif_id)
already_done_ids <- unique(already_done_ids)
message(paste0(length(already_done_ids), " species already done across sequential cache + all partitions."))
remaining_all <- candidates %>% filter(!(gbif_id %in% already_done_ids))

## Create Static Partition Split ------------------------
my_slice <- remaining_all[(seq_len(nrow(remaining_all)) %% n_partitions) == (partition_id %% n_partitions), ]
message(paste0("This worker's slice: ", nrow(my_slice), " of ", nrow(remaining_all), " remaining candidates."))
part_cache_path <- file.path(out_dir, paste0(slug, "_cache_part", partition_id, ".rds"))
already_done <- if (file.exists(part_cache_path)) readRDS(part_cache_path) else NULL
remaining <- if (!is.null(already_done)) my_slice %>% filter(!(gbif_id %in% already_done$gbif_id)) else my_slice
message(paste0(nrow(my_slice) - nrow(remaining), " already checkpointed by this worker, ", nrow(remaining), " remaining."))

## Compute Range Shares ------------------------
if (nrow(remaining) > 0) {
    batch_ix <- split(seq_len(nrow(remaining)), ceiling(seq_len(nrow(remaining)) / batch_size))
    for (b in seq_along(batch_ix)) {
        batch <- remaining[batch_ix[[b]], ]
        message(paste0("\n=== [worker ", partition_id, "] ", run_taxon, " batch ", b, "/", length(batch_ix), " (", nrow(batch), " species) ===\n"))
        batch_result <- bind_rows(lapply(seq_len(nrow(batch)), function(i) {
            message(paste0("  [w", partition_id, " ", i, "/", nrow(batch), "] ", batch$species[i], " (clip=", batch$clip[i], ")..."))
            r <- run_alpha_hull(batch$gbif_id[i], batch$species[i], batch$clip[i])
            r$clip <- batch$clip[i]
            r$category <- batch$red_list_category_code[i]
            message(paste0("    -> weight=", ifelse(is.na(r$weight), "NA", round(r$weight * 100, 4)), "% ",
                ifelse(is.na(r$note), "", paste0("(", r$note, ")"))))
            r
        }))
        already_done <- bind_rows(already_done, batch_result)
        saveRDS(already_done, part_cache_path)
        message(paste0("  [worker ", partition_id, "] Checkpointed - ", nrow(already_done), " species saved to ", part_cache_path))
    }
}
message(paste0("\n=== Worker ", partition_id, "/", n_partitions, " for ", run_taxon, " finished its slice (", nrow(already_done), " species) ==="))
