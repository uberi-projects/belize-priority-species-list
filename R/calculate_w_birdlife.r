# calculate_w_birdlife.r

## Source Objects ------------------------
source("R/build_belize_boundary.r")

## Check Required Data ------------------------
gpkg_path <- "birdlife_ranges/BOTW_2025.gpkg"
if (!file.exists(gpkg_path)) {
    stop("birdlife_ranges/BOTW_2025.gpkg not found - see README.md to get your own copy.")
}

## Fetch Candidate List ------------------------
bird_candidates <- belize_redlist_birds %>%
    distinct(species, gbif_id) %>%
    filter(!is.na(species))

## Query BirdLife Ranges ------------------------
message(paste0("Querying BirdLife range maps for ", nrow(bird_candidates), " Belize bird candidates..."))
escaped_names <- gsub("'", "''", bird_candidates$species)
name_list <- paste0("'", escaped_names, "'", collapse = ",")
query <- paste0(
    "SELECT sisid, sci_name, presence, origin, seasonal, geom FROM all_species ",
    "WHERE sci_name IN (", name_list, ") ",
    "AND presence IN (1,2) AND origin IN (1,2) AND seasonal IN (1,2,3)"
)
t0 <- Sys.time()
raw <- st_read(gpkg_path, query = query, quiet = TRUE) %>% st_make_valid()
message(paste0(
    "  Retrieved ", nrow(raw), " matching range-map features for ",
    length(unique(raw$sci_name)), " species in ", round(as.numeric(Sys.time() - t0, units = "secs")), "s"
))
matched_species <- unique(raw$sci_name)
unmatched <- setdiff(bird_candidates$species, matched_species)
if (length(unmatched) > 0) {
    message(paste0(
        "  ", length(unmatched), " candidate(s) had no BirdLife polygon under this name (possible ",
        "taxonomy mismatch between BirdLife and GBIF, or genuinely no Extant/Native/non-Passage range) - left NA."
    ))
}

## Union And Intersect Ranges ------------------------
out <- list()
for (i in seq_along(matched_species)) {
    sp <- matched_species[i]
    message(paste0("[", i, "/", length(matched_species), "] ", sp, "..."))
    sp_features <- raw %>% filter(sci_name == sp)
    # double st_make_valid() needed - reprojection can crash (GEOS topology error) without it
    range_shape <- try(
        sp_features %>% st_transform(mollweide_crs) %>% st_make_valid() %>% st_union() %>% st_make_valid(),
        silent = TRUE
    )
    if (inherits(range_shape, "try-error")) {
        out[[sp]] <- data.frame(species = sp, weight_birdlife = NA_real_, n_features_birdlife = nrow(sp_features), note_birdlife = "union/validity failed")
        next
    }
    global_area_m2 <- as.numeric(sum(st_area(range_shape)))
    if (is.na(global_area_m2) || global_area_m2 == 0) {
        out[[sp]] <- data.frame(species = sp, weight_birdlife = NA_real_, n_features_birdlife = nrow(sp_features), note_birdlife = "global range area is zero")
        next
    }
    belize_part <- try(st_intersection(range_shape, st_transform(belize_boundary, mollweide_crs)), silent = TRUE)
    belize_area_m2 <- if (inherits(belize_part, "try-error") || length(belize_part) == 0) 0 else as.numeric(sum(st_area(belize_part)))
    weight <- belize_area_m2 / global_area_m2
    message(paste0("  Weight: ", round(weight, 6)))
    out[[sp]] <- data.frame(species = sp, weight_birdlife = weight, n_features_birdlife = nrow(sp_features), note_birdlife = NA_character_)
}
unmatched_rows <- data.frame(species = unmatched, weight_birdlife = NA_real_, n_features_birdlife = 0, note_birdlife = "no matching BirdLife polygon under this name")
weights_birdlife <- bind_rows(out) %>%
    bind_rows(unmatched_rows) %>%
    left_join(bird_candidates, by = "species") %>%
    select(gbif_id, species, weight_birdlife, n_features_birdlife, note_birdlife) %>%
    arrange(desc(weight_birdlife))
if (!dir.exists("outputs/national_lists")) dir.create("outputs/national_lists", recursive = TRUE)
saveRDS(weights_birdlife, "outputs/national_lists/weights_belize_birdlife.rds")
write.csv(weights_birdlife, "outputs/national_lists/weights_belize_birdlife.csv", row.names = FALSE, na = "")
message(paste0(
    sum(!is.na(weights_birdlife$weight_birdlife)), " of ", nrow(weights_birdlife),
    " Belize bird candidates got a computed BirdLife-polygon weight. ",
    length(unmatched), " had no matching polygon under their GBIF-backbone name."
))