# merge_alphahull_partitions.r

## Setup ------------------------
suppressMessages(library(dplyr))

## Define Merge Function ------------------------
merge_taxon <- function(run_taxon) {
    out_dir <- "outputs/national_lists/by_group_alpha"
    slug <- gsub("[^a-z0-9]+", "_", tolower(run_taxon))
    final_csv_path <- file.path(out_dir, paste0(slug, ".csv"))
    main_cache_path <- file.path(out_dir, paste0(slug, "_cache.rds"))
    pieces <- list()
    if (file.exists(main_cache_path)) pieces[["sequential"]] <- readRDS(main_cache_path)
    part_paths <- list.files(out_dir, pattern = paste0("^", slug, "_cache_part[0-9]+\\.rds$"), full.names = TRUE)
    for (p in part_paths) pieces[[p]] <- readRDS(p)
    if (length(pieces) == 0) stop(paste0("No cache files found for ", run_taxon, " - nothing to merge."))
    combined <- bind_rows(pieces)
    n_before_dedup <- nrow(combined)
    combined <- combined %>% distinct(gbif_id, .keep_all = TRUE)
    if (n_before_dedup != nrow(combined)) {
        message(paste0("  Note: ", n_before_dedup - nrow(combined), " duplicate gbif_id rows dropped (species computed by more than one source)."))
    }
    out <- combined %>%
        mutate(range_share_pct = if_else(!is.na(weight), paste0(sprintf("%.2f", round(weight * 100, 2)), "%"), NA_character_)) %>%
        arrange(desc(weight))
    write.csv(out, final_csv_path, row.names = FALSE, na = "")
    message(paste0(
        run_taxon, ": merged ", length(pieces), " cache file(s) into ", nrow(out), " species. ",
        sum(!is.na(out$weight)), " got a computed weight. ", sum(!is.na(out$weight) & out$weight >= 0.20), " at >=20% range share.\n",
        "Saved to ", final_csv_path
    ))

    coord_dir <- "outputs/national_lists/raw_coordinates"
    if (!dir.exists(coord_dir)) dir.create(coord_dir, recursive = TRUE)
    coord_cache <- list()
    main_coord_path <- file.path(coord_dir, paste0(slug, ".rds"))
    if (file.exists(main_coord_path)) coord_cache <- modifyList(coord_cache, readRDS(main_coord_path))
    coord_part_paths <- list.files(coord_dir, pattern = paste0("^", slug, "_part[0-9]+\\.rds$"), full.names = TRUE)
    for (p in coord_part_paths) coord_cache <- modifyList(coord_cache, readRDS(p))
    if (length(coord_cache) > 0) {
        saveRDS(coord_cache, main_coord_path)
        message(paste0("  Merged ", length(coord_part_paths), " coordinate cache part(s) into ", main_coord_path, " (", length(coord_cache), " species with cached points)."))
    }

    invisible(out)
}