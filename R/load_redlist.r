# load_redlist.r

## Use IUCN API to get Belize redlist (needs to be set in .Renviron) ------------------------
if (file.exists("outputs/intermediates/redlist/belize_redlist_noDD.rds")) {
    belize_redlist_noDD <- readRDS("outputs/intermediates/redlist/belize_redlist_noDD.rds")
    message("Read existing redlist file (found in outputs)")
} else {
    belize_redlist <- rl_countries("BZ", key = Sys.getenv("IUCN_REDLIST_KEY"), latest = TRUE)
    belize_redlist_noDD <- belize_redlist$assessments %>%
        filter(red_list_category_code != "DD") %>%
        select(taxon_scientific_name, red_list_category_code, year_published)
    saveRDS(belize_redlist_noDD, "outputs/intermediates/redlist/belize_redlist_noDD.rds")
}

## Collapse To Latest Assessment Per Species ------------------------
belize_redlist_noDD <- belize_redlist_noDD %>%
    group_by(taxon_scientific_name) %>%
    slice_max(year_published, n = 1, with_ties = FALSE) %>%
    ungroup()

## Create Taxonomy Batch Directory ------------------------
directory_batches <- "outputs/intermediates/redlist/batches"
if (!dir.exists(directory_batches)) {
    dir.create(directory_batches, recursive = TRUE)
}

## Resolve Taxonomy In Batches ------------------------
batch_indices <- split(
    seq_along(belize_redlist_noDD$taxon_scientific_name),
    cut(seq_along(belize_redlist_noDD$taxon_scientific_name), 25, labels = FALSE)
)
for (i in seq_along(batch_indices)) {
    batch_file <- paste0("outputs/intermediates/redlist/batches/taxonomy_batch_", i, ".rds")
    if (file.exists(batch_file)) {
        message("Skipping batch ", i, " (found in outputs)")
    } else {
        taxa <- belize_redlist_noDD$taxon_scientific_name[batch_indices[[i]]]
        taxonomy <- classification(taxa, db = "gbif", ask = FALSE, rank = "species")
        taxonomy <- taxonomy[!sapply(taxonomy, is.logical)]
        tax_df <- imap_dfr(taxonomy, function(.x, .y) {
            species_id <- if ("species" %in% .x$rank) {
                .x$id[.x$rank == "species"]
            } else {
                NA
            }
            .x %>%
                mutate(
                    original_species = .y,
                    gbif_id = species_id
                )
        }) %>%
            select(name, rank, original_species, gbif_id) %>%
            pivot_wider(
                names_from = rank,
                values_from = name,
                values_fn = ~ .x[1]
            )
        saveRDS(tax_df, batch_file)
    }
}

## Combine Batch Outputs ------------------------
files <- list.files("outputs/intermediates/redlist/batches", pattern = "^taxonomy_", full.names = TRUE)
belize_redlist_taxa <- lapply(files, function(f) {
    readRDS(f) %>% mutate(across(everything(), as.character))
}) %>%
    bind_rows() %>%
    distinct(gbif_id, .keep_all = TRUE) %>%
    left_join(belize_redlist_noDD, by = c("original_species" = "taxon_scientific_name"))

## Filter To Desired Taxa ------------------------
belize_redlist_mammals <- filter(belize_redlist_taxa, class == "Mammalia", !is.na(gbif_id))
belize_redlist_birds <- filter(belize_redlist_taxa, class == "Aves", !is.na(gbif_id))
belize_redlist_reptiles <- filter(belize_redlist_taxa, class == "Squamata", !is.na(gbif_id))
belize_redlist_turtles <- filter(belize_redlist_taxa, class == "Testudines", !is.na(gbif_id))
belize_redlist_amphibians <- filter(belize_redlist_taxa, class == "Amphibia", !is.na(gbif_id))
belize_redlist_corals <- filter(belize_redlist_taxa, class == "Anthozoa", !is.na(gbif_id))

## Create FishBase Directory ------------------------
directory_fishbase <- "outputs/intermediates/fishbase"
if (!dir.exists(directory_fishbase)) {
    dir.create(directory_fishbase, recursive = TRUE)
}

## Filter Fish Via FishBase ------------------------
if (file.exists("outputs/intermediates/fishbase/fb_countries.rds")) {
    fb_countries <- readRDS("outputs/intermediates/fishbase/fb_countries.rds")
    message("Read existing fb countries file (found in outputs)")
} else {
    fb_countries <- fb_tbl("country")
    saveRDS(fb_countries, "outputs/intermediates/fishbase/fb_countries.rds")
}
if (file.exists("outputs/intermediates/fishbase/fb_species.rds")) {
    fb_species <- readRDS("outputs/intermediates/fishbase/fb_species.rds")
    message("Read existing fb species file (found in outputs)")
} else {
    fb_species <- fb_tbl("species")
    saveRDS(fb_species, "outputs/intermediates/fishbase/fb_species.rds")
}
if (file.exists("outputs/intermediates/fishbase/fb_belize_species.rds")) {
    fb_belize_species <- readRDS("outputs/intermediates/fishbase/fb_belize_species.rds")
    message("Read existing fb Belize species file (found in outputs)")
} else {
    fb_belize_species <- fb_countries %>%
        filter(C_Code == "084") %>%
        select(SpecCode, Freshwater, Brackish, Saltwater) %>%
        left_join(select(fb_species, SpecCode, Genus, Species, FamCode), by = "SpecCode") %>%
        mutate(taxon_scientific_name = paste(Genus, Species), Habitats = Freshwater + Brackish + Saltwater) %>%
        select(-SpecCode) %>%
        distinct() %>%
        rowwise() %>%
        mutate(
            gbif_match = list(name_backbone(name = taxon_scientific_name))
        ) %>%
        unnest_wider(gbif_match)
    fb_belize_species <- select(fb_belize_species, speciesKey, taxon_scientific_name, species, Freshwater, Brackish, Saltwater, Habitats)
    saveRDS(fb_belize_species, "outputs/intermediates/fishbase/fb_belize_species.rds")
}
belize_redlist_taxa_fishbase <- fb_belize_species %>%
    distinct(taxon_scientific_name, species, .keep_all = TRUE) %>%
    mutate(gbif_id = speciesKey) %>%
    left_join(distinct(belize_redlist_taxa, gbif_id, .keep_all = TRUE) %>% select(gbif_id, species), by = "gbif_id") %>%
    filter(!is.na(Habitats)) %>%
    mutate(species = species.y) %>%
    left_join(belize_redlist_noDD, by = "taxon_scientific_name")
belize_redlist_fish_freshwater <- filter(belize_redlist_taxa_fishbase, Freshwater == "1" & Habitats == 1, !is.na(gbif_id))
belize_redlist_fish_marine <- filter(belize_redlist_taxa_fishbase, Saltwater == "1" & Habitats == 1, !is.na(gbif_id))
belize_redlist_fish_mixed <- filter(belize_redlist_taxa_fishbase, Habitats > 1, !is.na(gbif_id))