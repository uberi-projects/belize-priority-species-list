# screen_gbif_checklist_gaps.r

## Setup ------------------------
suppressMessages(library(rgbif))
min_belize_share <- 0.02

## Define Focus Taxa ------------------------
focus_taxa <- list(
    Mammals = list(rank = "class", names = "Mammalia"),
    Birds = list(rank = "class", names = "Aves"),
    Reptiles = list(rank = "class", names = c("Squamata", "Testudines", "Crocodylia")),
    Amphibians = list(rank = "class", names = "Amphibia"),
    `Sharks & Rays` = list(rank = "class", names = c("Elasmobranchii", "Holocephali")),
    Insects = list(rank = "class", names = "Insecta"),
    Mollusks = list(rank = "class", names = c("Gastropoda", "Bivalvia", "Cephalopoda", "Polyplacophora", "Scaphopoda")),
    Corals = list(rank = "class", names = c("Anthozoa", "Hydrozoa")),
    Fungi = list(rank = "kingdom", names = "Fungi"),
    Plants = list(rank = "kingdom", names = "Plantae")
)

## Resolve Taxon Keys ------------------------
resolve_key <- function(name, rank) {
    bb <- name_backbone(name = name, rank = rank)
    if (is.null(bb$usageKey)) NA_character_ else as.character(bb$usageKey)
}

## Fetch Species Keys ------------------------
# Facets are paginated (GBIF caps a single facet page) - loop with facetOffset until a page comes
# back short of the page size requested.
fetch_species_keys <- function(key_field, key_value) {
    all_keys <- character()
    offset <- 0
    page_size <- 1000
    repeat {
        args <- list(
            country = "BZ", hasCoordinate = TRUE, hasGeospatialIssue = FALSE,
            facet = "speciesKey", facetLimit = page_size, facetOffset = offset, limit = 0
        )
        args[[key_field]] <- key_value
        res <- do.call(occ_search, args)
        facet_df <- res$facets$speciesKey
        if (is.null(facet_df) || nrow(facet_df) == 0) break
        all_keys <- c(all_keys, as.character(facet_df$name))
        if (nrow(facet_df) < page_size) break
        offset <- offset + page_size
    }
    unique(all_keys)
}

## Build Missing-Species List ------------------------
missing_cache_path <- "outputs/gbif_checklist_missing_species.rds"
if (file.exists(missing_cache_path)) {
    message("Read existing missing-species list (found in outputs)")
    missing_all <- readRDS(missing_cache_path)
} else {
    missing_list <- list()
    for (taxon in names(focus_taxa)) {
        spec <- focus_taxa[[taxon]]
        message(paste0("Deriving missing-species list for ", taxon, "..."))
        keys <- sapply(spec$names, resolve_key, rank = spec$rank)
        key_field <- switch(spec$rank, class = "classKey", kingdom = "kingdomKey")
        gbif_species <- unique(unlist(lapply(keys[!is.na(keys)], function(k) fetch_species_keys(key_field, k))))
        our_pool <- belize_redlist_taxa %>% filter(class %in% spec$names, !is.na(gbif_id)) %>% pull(gbif_id) %>% unique()
        missing_keys <- setdiff(gbif_species, our_pool)
        # data.frame(taxon = <scalar>, gbif_id = character(0)) errors ("differing number of
        # rows") rather than giving a 0-row frame - guard explicitly for a taxon with no gaps.
        missing_list[[taxon]] <- if (length(missing_keys) > 0) {
            data.frame(taxon = taxon, gbif_id = missing_keys, stringsAsFactors = FALSE)
        } else {
            data.frame(taxon = character(0), gbif_id = character(0), stringsAsFactors = FALSE)
        }
    }
    missing_all <- bind_rows(missing_list)
    saveRDS(missing_all, missing_cache_path)
}
message(paste0(nrow(missing_all), " total missing species to screen across ", length(unique(missing_all$taxon)), " taxa."))

## Select Remaining Species ------------------------
screen_cache_path <- "outputs/gbif_checklist_screen_results.rds"
already_done <- if (file.exists(screen_cache_path)) readRDS(screen_cache_path) else NULL
remaining <- if (!is.null(already_done)) {
    missing_all %>% filter(!(gbif_id %in% already_done$gbif_id))
} else {
    missing_all
}
message(paste0(nrow(missing_all) - nrow(remaining), " already checkpointed, ", nrow(remaining), " remaining."))

## Define Screening Function ------------------------
# Belize record share (>=2%) alone is the gate - not the original total-count OR share dual
# condition, which let almost everything through (e.g. 82% of mammals) since a species having few
# GBIF records anywhere isn't the same as Belize being disproportionately important for it.
# Defensive against NULL/NA/length-0 responses at every step: a failed occ_data() call returns
# NULL, and NULL$meta$count is NULL (not NA), which broke a bare if() on an earlier version of
# this function partway through a multi-hour run ("missing value where TRUE/FALSE needed").
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

## Screen Remaining Species ------------------------
batch_size <- 200
if (nrow(remaining) > 0) {
    batch_ix <- split(seq_len(nrow(remaining)), ceiling(seq_len(nrow(remaining)) / batch_size))
    for (b in seq_along(batch_ix)) {
        batch <- remaining[batch_ix[[b]], ]
        message(paste0(
            "\n=== Batch ", b, "/", length(batch_ix), " (", nrow(batch), " species, ",
            nrow(missing_all) - nrow(remaining) + sum(lengths(batch_ix[seq_len(b - 1)])), " done so far) ===\n"
        ))
        batch_result <- bind_rows(lapply(seq_len(nrow(batch)), function(i) {
            r <- screen_one(batch$gbif_id[i])
            r$taxon <- batch$taxon[i]
            r
        }))
        already_done <- bind_rows(already_done, batch_result)
        saveRDS(already_done, screen_cache_path)
        message(paste0("  Checkpointed - ", nrow(already_done), " species saved to ", screen_cache_path))
    }
}

## Report Summary ------------------------
summary_by_taxon <- already_done %>%
    group_by(taxon) %>%
    summarise(
        total = n(),
        clears_gate = sum(clears_gate, na.rm = TRUE),
        screened_out = sum(!clears_gate, na.rm = TRUE),
        failed = sum(is.na(clears_gate)),
        .groups = "drop"
    )
print(as.data.frame(summary_by_taxon))
message(paste0(
    "\n", sum(already_done$clears_gate, na.rm = TRUE), " of ", nrow(already_done),
    " missing species clear the gate and would be worth the full weight computation. ",
    sum(!already_done$clears_gate, na.rm = TRUE), " screened out as too widespread. ",
    sum(is.na(already_done$clears_gate)), " failed the count probe (retriable)."
))
