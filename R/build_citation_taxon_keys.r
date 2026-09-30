# build_citation_taxon_keys.r

## Collect Taxon Keys ------------------------
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
keys <- unique(unlist(lapply(groups, function(g) {
    read.csv(file.path("outputs/national_lists/by_group_alpha", paste0(g, ".csv")), colClasses = c(gbif_id = "character"))$gbif_id
})))

## Export Taxon Keys ------------------------
saveRDS(keys, "outputs/gbif_download_taxon_keys.rds")
message(paste0(length(keys), " unique GBIF taxon keys across all 11 taxa -> outputs/gbif_download_taxon_keys.rds"))
