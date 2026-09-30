# Belize Priority Species List

## Using this Repository

By using the following steps, the repository can be set up, run, and modified as needed.
1. Create `.Renviron` in the root and populate it according to `.Renviron.example`.
2. Place required user-supplied files into their appropriate folders. See section "Acquiring Data" below for details.
3. Run `setup.r`

## Repository Structure

**`basemap/`**
`basemap/` is an empty folder which is intended to hold user-provided shapefiles.

**`birdlife_ranges/`**
`birdlife_ranges/` is an empty folder which is intended to hold user-provided BirdLife species ranges data.

**`data/`**
`data/` contains reference data, such as the table of nationally threated species

**`outputs/`**
`outputs/`contains any outputs resulting from the scripts

**`R/`**
`R/`contains R code to create the Belize Priority Species List
1. Calculate Belize range-share for all Belizean IUCN-assessed birds using BirdLife's species range-maps. See section "Acquiring Data," for information on how to acquire these maps for use in this script. Range is calculated as union of every BirdLife polygon for that species where range is "Extant," or "Probably Extant," where origin is "Native," or "Reintroduced," and where seasonal is "Resident", "Breeding", or "Non-breeding".
2. `load_redlist.r` fetches RedList data from IUCN, fetch taxonomic data, link data to GBIF species, and filter to desired taxonomic groups, using FishBase for fish taxonomic data. Save results in batches to `outputs/`.
3. `spatial_weight_functions.r` builds combined Belize political and maritime boundary and equal-area projection (mollweide_crs).


**`renv/`**
`renv/`organizes dependencies

**`/`**
`/` contains various key files to run the project


## Data

### Acquiring Data

Several datasets need to be acquired and placed in the appropriate repository folders before the scripts will work.

**Shapefiles**
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
