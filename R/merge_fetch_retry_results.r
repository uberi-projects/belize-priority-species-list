# merge_fetch_retry_results.r

## Setup ------------------------
suppressMessages(library(dplyr))

## Load Retry Results ------------------------
cache_dir <- "outputs/intermediates/primary/by_group"
results_dir <- "outputs/results/primary/by_group_all"
parts <- list.files(cache_dir, pattern = "^fetch_retry_part[0-9]+\\.rds$", full.names = TRUE)
retried <- bind_rows(lapply(parts, readRDS))
message(paste0(nrow(retried), " retried species to merge in."))

## Merge Retry Results ------------------------
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
for (g in groups) {
    csv_path <- file.path(results_dir, paste0(g, ".csv"))
    d <- read.csv(csv_path, stringsAsFactors = FALSE, colClasses = c(gbif_id = "character"))
    this_group_retries <- retried %>% filter(taxon == g)
    if (nrow(this_group_retries) == 0) next

    n_replaced <- sum(d$gbif_id %in% this_group_retries$gbif_id)
    # carry over the correct clip/category per species from the original rows before dropping them
    orig_meta <- d %>% filter(gbif_id %in% this_group_retries$gbif_id) %>% select(gbif_id, clip, category)
    d <- d %>% filter(!(gbif_id %in% this_group_retries$gbif_id))

    replacement_rows <- this_group_retries %>%
        select(gbif_id, species, n_points, alpha, n_parts, global_area_km2, belize_area_km2, weight, note) %>%
        left_join(orig_meta, by = "gbif_id")

    d <- bind_rows(d, replacement_rows)
    write.csv(d, csv_path, row.names = FALSE, na = "")
    message(paste0(g, ": replaced ", n_replaced, " rows (", sum(!is.na(this_group_retries$weight)), " now have a real weight)."))
}
message("\nDone merging. Now re-run R/export_alpha_results_by_group.r to update the formatted deliverable files.")
