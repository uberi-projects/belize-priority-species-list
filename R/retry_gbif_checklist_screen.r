# retry_gbif_checklist_screen.r

## Setup ------------------------
suppressMessages(library(rgbif))
min_belize_share <- 0.02

## Select Retry Candidates ------------------------
screen_cache_path <- "outputs/gbif_checklist_screen_results.rds"
all_results <- readRDS(screen_cache_path)
retry_candidates <- all_results %>% filter(is.na(clears_gate)) %>% select(gbif_id, species, taxon)
message(paste0(nrow(retry_candidates), " species need a retry (stuck on a genuine count-probe failure)."))

## Define Screening Function ------------------------
# Defensive against NULL/NA/length-0 responses at every step - see screen_gbif_checklist_gaps.r
# for the crash this guards against ("missing value where TRUE/FALSE needed", mid multi-hour run).
screen_one <- function(gbif_id) {
    total_probe <- tryCatch(
        occ_data(taxonKey = gbif_id, hasCoordinate = TRUE, hasGeospatialIssue = FALSE, limit = 1),
        error = function(e) NULL
    )
    total_gbif_count <- NA_integer_
    if (!is.null(total_probe) && !is.null(total_probe$meta) && !is.null(total_probe$meta$count) &&
        length(total_probe$meta$count) == 1) {
        total_gbif_count <- total_probe$meta$count
    }
    species_name <- NA_character_
    if (!is.null(total_probe) && is.data.frame(total_probe$data) && nrow(total_probe$data) > 0 &&
        "species" %in% names(total_probe$data)) {
        nm <- total_probe$data$species[1]
        if (!is.null(nm) && length(nm) == 1 && !is.na(nm)) species_name <- nm
    }

    belize_probe <- tryCatch(
        occ_data(taxonKey = gbif_id, country = "BZ", hasCoordinate = TRUE, hasGeospatialIssue = FALSE, limit = 1),
        error = function(e) NULL
    )
    belize_gbif_count <- NA_integer_
    if (!is.null(belize_probe) && !is.null(belize_probe$meta) && !is.null(belize_probe$meta$count) &&
        length(belize_probe$meta$count) == 1) {
        belize_gbif_count <- belize_probe$meta$count
    }

    if (is.na(total_gbif_count)) {
        return(data.frame(gbif_id = gbif_id, species = species_name, total_gbif_count = NA_integer_,
                           belize_gbif_count = NA_integer_, belize_share = NA_real_, clears_gate = NA))
    }
    belize_share <- NA_real_
    if (!is.na(belize_gbif_count) && total_gbif_count > 0) {
        belize_share <- belize_gbif_count / total_gbif_count
    }
    clears_gate <- isTRUE(!is.na(belize_share) && belize_share >= min_belize_share)

    data.frame(gbif_id = gbif_id, species = species_name, total_gbif_count = total_gbif_count,
               belize_gbif_count = belize_gbif_count, belize_share = round(belize_share, 4), clears_gate = clears_gate)
}

## Select Remaining Species ------------------------
retry_cache_path <- "outputs/gbif_checklist_retry_results.rds"
retried_so_far <- if (file.exists(retry_cache_path)) readRDS(retry_cache_path) else NULL
remaining <- if (!is.null(retried_so_far)) {
    retry_candidates %>% filter(!(gbif_id %in% retried_so_far$gbif_id))
} else {
    retry_candidates
}
message(paste0(nrow(retry_candidates) - nrow(remaining), " already retried, ", nrow(remaining), " remaining."))

## Retry Remaining Species ------------------------
batch_size <- 100
if (nrow(remaining) > 0) {
    batch_ix <- split(seq_len(nrow(remaining)), ceiling(seq_len(nrow(remaining)) / batch_size))
    for (b in seq_along(batch_ix)) {
        batch <- remaining[batch_ix[[b]], ]
        message(paste0("\n=== Retry batch ", b, "/", length(batch_ix), " (", nrow(batch), " species) ===\n"))
        batch_result <- bind_rows(lapply(seq_len(nrow(batch)), function(i) {
            r <- screen_one(batch$gbif_id[i])
            r$taxon <- batch$taxon[i]
            r
        }))
        retried_so_far <- bind_rows(retried_so_far, batch_result)
        saveRDS(retried_so_far, retry_cache_path)
        message(paste0("  Checkpointed - ", nrow(retried_so_far), " retried so far."))
    }
}

## Merge Retry Results ------------------------
still_failed_ids <- retried_so_far$gbif_id[is.na(retried_so_far$clears_gate)]
merged <- bind_rows(
    all_results %>% filter(!(gbif_id %in% retried_so_far$gbif_id)),
    retried_so_far
)
saveRDS(merged, screen_cache_path)

n_recovered <- sum(!is.na(retried_so_far$clears_gate))
message(paste0(
    "\n", n_recovered, " of ", nrow(retried_so_far), " retried species recovered a real result. ",
    length(still_failed_ids), " still stuck - rerun this script again if that's non-zero.\n",
    sum(merged$clears_gate, na.rm = TRUE), " of ", nrow(merged), " total species now clear the gate."
))
