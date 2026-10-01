# export_alpha_extended_by_group.r

## Setup ------------------------
suppressMessages(library(dplyr))

## Load Screen And Weight Results ------------------------
screened <- readRDS("outputs/intermediates/extended/gbif_checklist_screen_results.rds")
weighted <- readRDS("outputs/intermediates/extended/gbif_checklist_gap_weights_alpha.rds") %>%
    select(gbif_id, weight, n_points) %>%
    distinct(gbif_id, .keep_all = TRUE)

## Build Combined Table ------------------------
combined <- screened %>%
    left_join(weighted, by = "gbif_id") %>%
    mutate(
        record_share_pct = if_else(!is.na(belize_share), paste0(sprintf("%.2f", round(belize_share * 100, 2)), "%"), NA_character_),
        clears_screen = case_when(clears_gate ~ "Yes", !clears_gate ~ "No", TRUE ~ NA_character_),
        range_share_pct = if_else(!is.na(weight), paste0(sprintf("%.2f", round(weight * 100, 2)), "%"), NA_character_),
        discovery = case_when(is.na(weight) ~ NA_character_, weight >= 0.20 ~ "Yes", TRUE ~ "No")
    ) %>%
    arrange(desc(coalesce(weight, belize_share, -1))) %>%
    transmute(
        `Taxonomic Group` = taxon,
        Species = species,
        `Record Share` = record_share_pct,
        `Clears Screen` = clears_screen,
        `Range Share` = range_share_pct,
        Sample = n_points,
        `Discovery (>=20%)` = discovery
    )

## Export Per-Group CSVs ------------------------
out_dir <- "outputs/results/extended/by_group"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
for (g in unique(combined$`Taxonomic Group`)) {
    slug <- gsub("[^a-z0-9]+", "_", tolower(g))
    out_path <- file.path(out_dir, paste0("checklist_gap_", slug, ".csv"))
    write.csv(combined %>% filter(`Taxonomic Group` == g) %>% select(-`Taxonomic Group`), out_path, row.names = FALSE, na = "")
    message(paste0(g, ": ", sum(combined$`Taxonomic Group` == g), " species -> ", out_path))
}

## Export Combined Discoveries File ------------------------
discoveries_only <- combined %>% filter(`Discovery (>=20%)` == "Yes")
combined_out_path <- "outputs/results/extended/belize_priority_species_list_alpha_extension.csv"
write.csv(discoveries_only, combined_out_path, row.names = FALSE, na = "")
message(paste0("\nCombined (>=20% discoveries only): ", nrow(discoveries_only), " species -> ", combined_out_path))
