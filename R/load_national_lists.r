# load_national_lists.r

## Read Compiled Source Table ------------------------
national_lists_raw <- read.csv(
    "data/national_priority_lists/Belize_Threatened_Species_Table.csv",
    stringsAsFactors = FALSE
)

## Split Scientific And Common Names ------------------------
is_tree_source <- grepl("^Trees Workshop Report", national_lists_raw$Source)
has_parens <- grepl("\\(.*\\)$", national_lists_raw$Species)
inside_parens <- trimws(sub(".*\\(([^)]+)\\)$", "\\1", national_lists_raw$Species))
outside_parens <- trimws(sub("\\s*\\([^)]+\\)$", "", national_lists_raw$Species))
national_lists <- national_lists_raw %>%
    mutate(
        scientific_name = ifelse(is_tree_source, outside_parens, ifelse(has_parens, inside_parens, outside_parens)),
        common_name = ifelse(is_tree_source, ifelse(has_parens, inside_parens, NA), ifelse(has_parens, outside_parens, NA)),
        source_short = case_when(
            grepl("^Trees Workshop Report", Source) ~ "tree_global_iucn",
            grepl("^National Red List", Source) ~ "national_2025",
            grepl("^National Threatened Avian", Source) ~ "national_2020",
            TRUE ~ "other"
        )
    ) %>%
    select(scientific_name, common_name, source_short, Ranking)

## Collapse Duplicate Entries ------------------------
category_severity <- c(CR = 1, EN = 2, VU = 3, NT = 4, "Watch List (NT/LC/DD)" = 5, "NT/LC" = 5)
national_lists <- national_lists %>%
    mutate(severity = category_severity[Ranking]) %>%
    group_by(scientific_name, source_short) %>%
    slice_min(severity, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(-severity)

## Extract Common Names ------------------------
common_names <- national_lists %>%
    group_by(scientific_name) %>%
    summarize(common_name = first(na.omit(common_name)), .groups = "drop")

## Pivot To Wide Format ------------------------
national_lists_wide <- national_lists %>%
    select(scientific_name, source_short, Ranking) %>%
    pivot_wider(names_from = source_short, values_from = Ranking, values_fn = ~ .x[1]) %>%
    left_join(common_names, by = "scientific_name")

## Define Synonym Corrections ------------------------
scientific_name_synonyms <- c(
    "Trichilia minutiflora" = "Trichilia americana"
)

## Process Data ------------------------
national_lists_wide <- national_lists_wide %>%
    mutate(
        gbif_lookup_name = ifelse(
            scientific_name %in% names(scientific_name_synonyms),
            unname(scientific_name_synonyms[scientific_name]),
            scientific_name
        ),
        dropped_after_2020 = !is.na(national_2020) & is.na(national_2025),
        known_endemic = scientific_name == "Gymnanthes belizensis",
        notes = case_when(
            dropped_after_2020 ~ "In 2020 avian list but absent from 2025 national list - kept in for now; confirm status later.",
            scientific_name == "Harpalyce torresii" ~ "Uncertain ID in source report (Harpalyce rupicola / torresii) - flagged for taxonomic QA.",
            known_endemic ~ "Flagged as endemic in source report - if GBIF data is too sparse to build a hull, treat as near-100% Belize weight rather than dropping.",
            gbif_lookup_name != scientific_name ~ paste0("Resolved via accepted name '", gbif_lookup_name, "' for GBIF lookup."),
            TRUE ~ NA_character_
        )
    )

## Resolve GBIF Taxon Keys ------------------------
directory_national_lists <- "outputs/national_lists"
if (!dir.exists(directory_national_lists)) {
    dir.create(directory_national_lists, recursive = TRUE)
}
taxonomy_file <- file.path(directory_national_lists, "national_lists_taxonomy.rds")
if (file.exists(taxonomy_file)) {
    tax_df <- readRDS(taxonomy_file)
    message("Read existing national lists taxonomy file (found in outputs)")
} else {
    taxonomy <- classification(unique(national_lists_wide$gbif_lookup_name), db = "gbif", ask = FALSE, rank = "species")
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
    saveRDS(tax_df, taxonomy_file)
}
national_lists_resolved <- national_lists_wide %>%
    left_join(tax_df, by = c("gbif_lookup_name" = "original_species")) %>%
    mutate(unresolved = is.na(gbif_id))

## Resolve Fallback Taxonomy ------------------------
fallback_file <- file.path(directory_national_lists, "national_lists_taxonomy_fallback.rds")
still_unresolved <- national_lists_resolved$gbif_lookup_name[national_lists_resolved$unresolved]
if (length(still_unresolved) > 0) {
    nz <- function(x) if (is.null(x) || length(x) == 0) NA else x
    if (file.exists(fallback_file)) {
        fallback_df <- readRDS(fallback_file)
        message("Read existing fallback taxonomy file (found in outputs)")
    } else {
        fallback_df <- map_dfr(still_unresolved, function(nm) {
            res <- name_backbone(name = nm)
            data.frame(
                gbif_lookup_name = nm,
                fb_gbif_id = if (isTRUE(nz(res$rank) == "SPECIES")) as.character(res$speciesKey) else NA,
                fb_kingdom = nz(res$kingdom), fb_phylum = nz(res$phylum),
                fb_class = nz(res$class), fb_order = nz(res$order),
                fb_family = nz(res$family), fb_genus = nz(res$genus),
                fb_species = nz(res$species), fb_matchType = nz(res$matchType),
                stringsAsFactors = FALSE
            )
        })
        saveRDS(fallback_df, fallback_file)
    }
    national_lists_resolved <- national_lists_resolved %>%
        left_join(fallback_df, by = "gbif_lookup_name") %>%
        mutate(
            gbif_id = coalesce(as.character(gbif_id), as.character(fb_gbif_id)),
            kingdom = coalesce(kingdom, fb_kingdom), phylum = coalesce(phylum, fb_phylum),
            class = coalesce(class, fb_class), order = coalesce(order, fb_order),
            family = coalesce(family, fb_family), genus = coalesce(genus, fb_genus),
            species = coalesce(species, fb_species),
            notes = case_when(
                !is.na(fb_gbif_id) & fb_matchType != "EXACT" ~ paste0(coalesce(notes, ""), " [fallback GBIF match is ", fb_matchType, " - verify]"),
                TRUE ~ notes
            )
        ) %>%
        select(-starts_with("fb_")) %>%
        mutate(unresolved = is.na(gbif_id))
}

## Add Criterion-1 Species ------------------------
if (exists("belize_redlist_noDD") && exists("belize_redlist_taxa")) {
    nt_or_worse_resolved <- belize_redlist_taxa %>%
        filter(red_list_category_code %in% c("NT", "VU", "EN", "CR", "LR/nt"), !is.na(gbif_id)) %>%
        distinct(gbif_id, .keep_all = TRUE)
    criterion1_additions <- nt_or_worse_resolved %>%
        filter(!(gbif_id %in% national_lists_resolved$gbif_id)) %>%
        transmute(
            scientific_name = original_species,
            common_name = NA_character_,
            national_2025 = NA_character_,
            national_2020 = NA_character_,
            tree_global_iucn = NA_character_,
            gbif_lookup_name = species,
            dropped_after_2020 = FALSE,
            known_endemic = FALSE,
            notes = paste0(
                "Added via direct IUCN Belize criterion-1 expansion (", red_list_category_code,
                ", not in the compiled source documents)."
            ),
            gbif_id, kingdom, phylum, class, order, family, genus, species,
            unresolved = FALSE
        )
    national_lists_resolved <- bind_rows(national_lists_resolved, criterion1_additions)
    message(paste0(
        nrow(criterion1_additions), " species added via direct IUCN criterion-1 expansion (any taxonomic class)."
    ))
} else {
    warning(
        "belize_redlist_noDD/belize_redlist_taxa not found in the environment - source load_redlist.r ",
        "BEFORE this script to include the direct IUCN criterion-1 expansion. Proceeding without it."
    )
}

## Export For Review ------------------------
saveRDS(national_lists_resolved, file.path(directory_national_lists, "national_lists_resolved.rds"))
write.csv(national_lists_resolved, file.path(directory_national_lists, "national_lists_resolved.csv"), row.names = FALSE)
message(paste0(
    nrow(national_lists_resolved), " unique species across all three lists, ",
    sum(national_lists_resolved$unresolved), " unresolved against GBIF backbone."
))
