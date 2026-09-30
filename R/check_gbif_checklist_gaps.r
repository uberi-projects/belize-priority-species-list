# check_gbif_checklist_gaps.r

## Setup ------------------------
suppressMessages(library(rgbif))

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

## Compare Against Candidate Pool ------------------------
results <- list()
for (taxon in names(focus_taxa)) {
    spec <- focus_taxa[[taxon]]
    message(paste0("=== ", taxon, " ==="))
    keys <- sapply(spec$names, resolve_key, rank = spec$rank)
    message(paste0("  Resolved GBIF ", spec$rank, " key(s): ", paste(spec$names, "=", keys, collapse = ", ")))

    key_field <- switch(spec$rank, class = "classKey", kingdom = "kingdomKey")
    gbif_species <- unique(unlist(lapply(keys[!is.na(keys)], function(k) fetch_species_keys(key_field, k))))
    message(paste0("  ", length(gbif_species), " distinct species with BZ occurrence records on GBIF"))

    our_pool <- belize_redlist_taxa %>%
        filter(class %in% spec$names, !is.na(gbif_id)) %>%
        pull(gbif_id) %>%
        unique()
    n_already <- sum(gbif_species %in% our_pool)
    n_missing <- length(gbif_species) - n_already
    message(paste0("  ", n_already, " already in our candidate pool, ", n_missing, " missing\n"))

    results[[taxon]] <- data.frame(
        taxon = taxon, gbif_total = length(gbif_species), already_covered = n_already, missing = n_missing
    )
}

## Export Summary ------------------------
summary_table <- bind_rows(results)
print(summary_table, row.names = FALSE)
saveRDS(summary_table, "outputs/gbif_checklist_gap_summary.rds")

message(paste0(
    "\nTotal missing across all focus taxa (excl. fish): ", sum(summary_table$missing)
))
