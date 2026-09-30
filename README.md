# Belize Priority Species List

## Using this Repository

By using the following steps, the repository can be set up, run, and modified as needed.
1. Create `.Renviron` in the root and populate it according to `.Renviron.example`.
2. Place required user-supplied files into their appropriate folders. See section "Acquiring Data" below for details.
3. Run `setup.r`
4. Run the pipeline. See "Running the Pipeline" below for the exact order and commands.

## Running the Pipeline

All commands below are run from the repo root. Steps 1-3 build the candidate pool and Belize
boundary; step 4 is the main computation (pick sequential OR parallel); steps 5-6 are optional
add-ons; step 7 produces the final deliverable.

**1. Build the candidate pool**: Construct list of candidates for the species priority list. Note that this step is very slow, due to many batched API calls.
```r
source("R/load_packages.r")
source("R/load_redlist.r")
source("R/load_national_lists.r")
```

**2. Build the Belize boundary**: Construct the Belize boundary using provided shapefiles.
```r
source("R/spatial_weight_functions.r")
```

**3. Compute alpha-hull range shares**: Calculate range shares in Belize using alpha-hull method. There are two options for this step. Sequential is simpler, and parallel faster for larger taxa:

Sequential, one taxon at a time, can run all taxa in one run. Run:
```r
source("R/load_packages.r")
source("R/load_redlist.r")
source("R/spatial_weight_functions.r")
source("R/calculate_w_alphahull_national_lists.r")
```
By default this fetches live GBIF data for every species. To replay from cached coordinates
instead, set `use_cached_coords <- TRUE` near the top of `calculate_w_alphahull_national_lists.r`
before running - see "Coordinate Caching & Replay Mode" below.

Parallel, for large taxa. No need to run the `source(...)` lines above first - each
`Rscript` call below starts a fresh R process and loads everything it needs on its own.
1. Pick a taxon. Valid values: `"Amphibians"`, `"Birds"`, `"Corals"`, `"Fish"`, `"Fungi"`, 
    `"Insects"`, `"Mammals"`, `"Mollusks"`, `"Plants"`, `"Reptiles"`, `"Sharks & Rays"`.
2. Decide how many workers to split the work across (recommendation is 3), and open that many separate
   terminal windows at the repo root.
3. In each terminal, run one line below. Start each one without waiting for the previous to
   finish (e.g. open terminal 1 and run its line, then without closing it open terminal 2 and run
   its line, and so on). The middle number is that terminal's own worker ID (1, 2, 3, ...), and
   the last number is the total worker count, which must be identical in every terminal:
```
Rscript R/calculate_w_alphahull_parallel_worker.r "Birds" 1 3
Rscript R/calculate_w_alphahull_parallel_worker.r "Birds" 2 3
Rscript R/calculate_w_alphahull_parallel_worker.r "Birds" 3 3
```
Add a 4th argument, `TRUE`, to any of these to replay from cached coordinates instead of fetching
live - see "Coordinate Caching & Replay Mode" below.

4. Once all workers for that taxon have finished, merge their results into the taxon's final CSV:
```r
source("R/merge_alphahull_partitions.r")
merge_taxon("Birds")
```
5. Repeat steps 1-4 for any other taxon you want to run in parallel. Any taxon you don't run this
   way still needs to go through the sequential option above - it automatically skips taxa whose
   final CSV already exists, so it's safe to run after parallel runs to pick up the rest.

**4. (Optional) Retry transient GBIF fetch failures.**: First build the retry input - not yet produced by any script, so build it directly:
```r
library(dplyr)
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
failed <- bind_rows(lapply(groups, function(g) {
    read.csv(file.path("outputs/national_lists/by_group_alpha", paste0(g, ".csv")), colClasses = c(gbif_id = "character")) %>%
        filter(note == "GBIF fetch failed after retries") %>%
        transmute(gbif_id, species, clip, taxon = g)
}))
saveRDS(failed, "outputs/national_lists/by_group_alpha/fetch_failed_for_retry.rds")
```
Then retry - sequential (simpler) or parallel (faster for a large retry set):

Sequential:
```
Rscript R/retry_gbif_fetch_failures.r 1 1
```

Parallel, in separate terminal windows (same pattern as step 3 - start each one without waiting
for the previous to finish, middle number is that terminal's worker ID, last number is the total
worker count and must match across all three):
```
Rscript R/retry_gbif_fetch_failures.r 1 3
Rscript R/retry_gbif_fetch_failures.r 2 3
Rscript R/retry_gbif_fetch_failures.r 3 3
```

Then merge - required after either option above, sequential or parallel:
```r
source("R/load_packages.r")
source("R/merge_fetch_retry_results.r")
```

**5. (Optional) BirdLife comparison weights for birds**: Add BirdLife comparison weights, as a second methodology for calculating range share. Needs `birdlife_ranges/BOTW_2025.gpkg`
acquired (see "Acquiring Data"):
```r
source("R/load_packages.r")
source("R/load_redlist.r")
source("R/calculate_w_birdlife.r")
```

**6. Export the final, reader-facing CSVs**: This exports a clean, usable set of csvs as results (works with or without step 5 - BirdLife columns
show "No Map Available" if step 5 was skipped):
```r
source("R/load_packages.r")
source("R/export_alpha_results_by_group.r")
```

**7. (Optional, not yet available) Submit a GBIF citation download.**: This creates a unique DOI for datasets used, for citation purposes
`submit_gbif_citation_download.r` needs `outputs/gbif_download_taxon_keys.rds`, which is meant to
be built by `R/build_citation_taxon_keys.r` - **that script doesn't exist yet** (planned, not yet
written). This step isn't runnable until it is.

## Redoing Work

Most scripts cache their results to `.rds` files in `outputs/` and automatically reuse them
instead of recomputing. This makes the pipeline resumable after a stop or crash, but it also
means re-running a script after changing an input won't redo work that's already cached. To force
a step to redo, delete the relevant cache file(s) first, then re-run the step.

| To redo... | Delete... |
|---|---|
| The IUCN Belize redlist fetch | `outputs/belize_redlist_noDD.rds` |
| Taxonomy resolution in `load_redlist.r` | `outputs/batches/` (all files, or just the batch(es) covering the species you want re-resolved) |
| FishBase data | `outputs/fishbase/fb_countries.rds`, `fb_species.rds`, `fb_belize_species.rds` |
| GBIF taxon-key resolution in `load_national_lists.r` | `outputs/national_lists/national_lists_taxonomy.rds` and `national_lists_taxonomy_fallback.rds` |
| A taxon's alpha-hull computation, entirely | `outputs/national_lists/by_group_alpha/<slug>.csv`, `<slug>_cache.rds`, and any `<slug>_cache_part*.rds` |
| ...and also force a live GBIF re-fetch rather than a coordinate replay | additionally delete `outputs/national_lists/raw_coordinates/<slug>.rds` and any `<slug>_part*.rds` |
| Just some species within a taxon (keep the rest cached) | remove those species' rows from `<slug>_cache.rds` / `<slug>_cache_part*.rds` |
| GBIF retry results | `fetch_retry_part*.rds` in `outputs/national_lists/by_group_alpha/` |
| Common-name lookups | `outputs/vernacular_names_cache.rds` |

`<slug>` is the taxon name, lowercased with spaces/symbols replaced by underscores (e.g. "Sharks &
Rays" -> `sharks_rays`).

Not cached - these always fully recompute and overwrite every time you run them: step 5
(`calculate_w_birdlife.r`), step 6 (`export_alpha_results_by_group.r`), and the merge scripts
(`merge_alphahull_partitions.r`, `merge_fetch_retry_results.r`).

## Coordinate Caching & Replay Mode

Step 3 caches the raw GBIF coordinate points it fetches for each species, separately from the
summary results, in `outputs/national_lists/raw_coordinates/` (`<slug>.rds` for the sequential
run, `<slug>_part<id>.rds` per parallel worker until `merge_taxon()` combines them). This backs
two run modes:

- **Fetch mode** (default): calls GBIF live for every species that isn't already done. Numbers
  may drift slightly from a previous run as GBIF's database grows.
- **Replay mode**: for any species with cached coordinates, skips the network call and reuses them
  directly - faster, and gives an exact, network-free reproduction of a previous run's numbers.
  Useful for testing a late-stage parameter change (an alpha-hull setting or clip rule) without
  re-fetching GBIF, or for verifying published numbers without relying on GBIF's live, growing
  database. Turn it on with `use_cached_coords <- TRUE` - for sequential, in `R/calculate_w_alphahull_national_lists.r`; for parallel, a 4th CLI argument, `TRUE`.

**Caveat**: both caches only track *whether* a species has been processed, not *what parameters*
it was processed under. If you change an alpha-hull parameter or clip rule (in
`alphahull_helpers.r`) and want that reflected, delete the relevant cache file(s) first (see
"Redoing Work" above) - otherwise a re-run, in either mode, just replays or skips the old result.

## Repository Structure

**`basemap/`** is an empty folder which is intended to hold user-provided shapefiles.

**`birdlife_ranges/` is an empty folder which is intended to hold user-provided BirdLife species ranges data.

**`data/`** contains reference data, such as the table of nationally threated species

**`outputs/`** contains any outputs resulting from the scripts

**`R/`** contains R code to create the Belize Priority Species List
1. `load_packages.r` installs and attaches required packages.
2. `load_redlist.r` fetches RedList data from IUCN, fetches taxonomic data, links data to GBIF species, and filters to desired taxonomic groups, using FishBase for fish taxonomic data. Saves results in batches to `outputs/`.
3. `load_national_lists.r` merges the national/global priority-species source lists (`data/`) with a direct IUCN pull into one candidate table with resolved GBIF taxon keys.
4. `spatial_weight_functions.r` builds the combined Belize political and maritime boundary and the equal-area projection (mollweide_crs).
5. `alphahull_helpers.r` holds shared candidate-pool and per-species alpha-hull logic used by the two runners below. Not meant to be run directly.
6. `calculate_w_alphahull_national_lists.r` runs the alpha-hull range-share calculation taxon by taxon, single-threaded, checkpointed.
7. `calculate_w_alphahull_parallel_worker.r` is the same calculation split across parallel processes, for the largest taxa.
8. `merge_alphahull_partitions.r` combines parallel workers' results into each taxon's final CSV.
9. `retry_gbif_fetch_failures.r` retries species that hit a transient GBIF fetch failure.
10. `merge_fetch_retry_results.r` merges retry results back into the per-taxon CSVs.
11. `calculate_w_birdlife.r` computes a second, independent range-share weight for birds from BirdLife's range maps. See "Acquiring Data" for how to get `BOTW_2025.gpkg`. Range is the union of every BirdLife polygon for a species where presence is "Extant" or "Probably Extant," origin is "Native" or "Reintroduced," and seasonal is "Resident," "Breeding," or "Non-breeding."
12. `export_alpha_results_by_group.r` builds the final, reader-facing per-taxon CSVs.
13. `submit_gbif_citation_download.r` submits a GBIF occurrence download covering the species pool used, for a citable DOI.

**`renv/`** manages pinned package versions (`renv.lock`).

**`/`** (repo root) holds `README.md`, `setup.r` (installs/restores packages), `DESCRIPTION` (declares dependencies for `renv`), `renv.lock`, `.Renviron.example`, and `LICENSE.txt`.


## Data

### Acquiring Data

Several datasets need to be acquired and placed in the appropriate repository folders before the scripts will work.

1. **`Belize_Basemap.shp`** (+ `.dbf`, `.prj`, `.shx`, `.shp.xml` sidecars) district-level
   shapefile (Meerman, 2013). http://www.biodiversity.bz. Place in `basemap/`.

2. **`land_belize.txt`** national land-boundary polygon (ArcGIS_DemoBz, 2023a). https://services.arcgis.com/lkHhAsiwtcKnwSeA/ArcGIS/rest/services/Belize_Country/FeatureServer/1/query?where=1=1&outFields=*&f=geojson. Place in `basemap/`.

3. **`maritime_belize.txt`** Belize's declared maritime jurisdiction, Territorial Sea +
   Exclusive Economic Zone (ArcGIS_DemoBz, 2023b). https://services.arcgis.com/lkHhAsiwtcKnwSeA/ArcGIS/rest/services/Belize_Nationalwaters/FeatureServer/0/query?where=1=1&outFields=*&f=geojson. Place in `basemap/`.

4. **`BOTW_2025.gpkg`** bird species distribution maps, used for BirdLife-based range-share
   weights (BirdLife International, 2025). Submit a data request at 
   http://datazone.birdlife.org/species/requestdis. Place in `birdlife_ranges/`.


### Pre-Included Data

1. **`Belize_Threatened_Species_Table.csv`**  list of species previously assessed as vulnerable  in Belize from Belize Forest Department (Belize Forest Department, 2025; Belize Forest Department Wildlife Programme, 2020).


## Literature Cited

ArcGIS_DemoBz. (2023a). Belize_Country [Feature layer] [Dataset]. ArcGIS Online. https://www.arcgis.com/home/item.html?id=09608485ef21491d9ea15a9a5f83fe20

ArcGIS_DemoBz. (2023b). Belize_Nationalwaters [Feature layer] [Dataset]. ArcGIS Online.

Belize Forest Department. (2025). Belize National Red List of Threatened Species: Mammals, Birds, Reptiles and Amphibians.

Belize Forest Department Wildlife Programme. (2020). National IUCN Red List for Threatened Avian Species—Belize.

BirdLife International and Handbook of the Birds of the World. (2025). Bird species distribution maps of the world (Version 2025.2) [Dataset]. http://datazone.birdlife.org/species/requestdis

Meerman, J. C. (2013). Belize Basemap [Dataset]. Biodiversity and Environmental Resource Data System of Belize. http://www.biodiversity.bz/
