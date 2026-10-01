# retry_gbif_fetch_failures.r

## Setup ------------------------
suppressMessages({
    library(sf)
    library(dplyr)
    library(rgbif)
    library(rangeBuilder)
})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript retry_gbif_fetch_failures.r <partition_id> <n_partitions>")
partition_id <- as.integer(args[1])
n_partitions <- as.integer(args[2])

## Source Scripts ------------------------
source("R/load_packages.r")
source("R/build_belize_boundary.r")
source("R/define_alphahull_helpers.r")

## Select Partition Slice ------------------------
out_dir <- "outputs/intermediates/primary/by_group"
failed <- readRDS(file.path(out_dir, "fetch_failed_for_retry.rds"))
message(paste0("Worker ", partition_id, "/", n_partitions, ": ", nrow(failed), " total species to retry."))
my_slice <- failed[(seq_len(nrow(failed)) %% n_partitions) == (partition_id %% n_partitions), ]
message(paste0("This worker's slice: ", nrow(my_slice), " species."))
part_cache_path <- file.path(out_dir, paste0("fetch_retry_part", partition_id, ".rds"))
already_done <- if (file.exists(part_cache_path)) readRDS(part_cache_path) else NULL
remaining <- if (!is.null(already_done)) my_slice %>% filter(!(gbif_id %in% already_done$gbif_id)) else my_slice
message(paste0(nrow(my_slice) - nrow(remaining), " already checkpointed, ", nrow(remaining), " remaining."))

## Retry Failed Species ------------------------
if (nrow(remaining) > 0) {
    for (i in seq_len(nrow(remaining))) {
        message(paste0("[w", partition_id, " ", i, "/", nrow(remaining), "] ", remaining$species[i], " (taxon=", remaining$taxon[i], ")..."))
        r <- run_alpha_hull(remaining$gbif_id[i], remaining$species[i], remaining$clip[i])
        r$taxon <- remaining$taxon[i]
        message(paste0("  -> ", ifelse(is.na(r$weight), paste0("still NA (", r$note, ")"), paste0("weight=", round(r$weight * 100, 4), "%"))))
        already_done <- bind_rows(already_done, r)
        saveRDS(already_done, part_cache_path)
    }
}
message(paste0("\nWorker ", partition_id, "/", n_partitions, " finished: ", nrow(already_done), " species, ",
    sum(!is.na(already_done$weight)), " recovered."))
