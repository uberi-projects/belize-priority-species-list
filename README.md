# Belize Priority Species List

## Acquiring Data

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


## Pre-Included Data

1. **`Belize_Threatened_Species_Table.csv`**  list of species previously assessed as vulnerable  in Belize from Belize Forest Department (Belize Forest Department, 2025; Belize Forest Department Wildlife Programme, 2020).


## Literature Cited

ArcGIS_DemoBz. (2023a). Belize_Country [Feature layer] [Dataset]. ArcGIS Online. https://www.arcgis.com/home/item.html?id=09608485ef21491d9ea15a9a5f83fe20
ArcGIS_DemoBz. (2023b). Belize_Nationalwaters [Feature layer] [Dataset]. ArcGIS Online.
Belize Forest Department. (2025). Belize National Red List of Threatened Species: Mammals, Birds, Reptiles and Amphibians.
Belize Forest Department Wildlife Programme. (2020). National IUCN Red List for Threatened Avian Species—Belize.
BirdLife International and Handbook of the Birds of the World. (2025). Bird species distribution maps of the world (Version 2025.2) [Dataset]. http://datazone.birdlife.org/species/requestdis
Meerman, J. C. (2013). Belize Basemap [Dataset]. Biodiversity and Environmental Resource Data System of Belize. http://www.biodiversity.bz/
