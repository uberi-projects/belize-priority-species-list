# Belize Priority Species List — Methods

## Description

The 2026 Belize Priority Species List builds upon existing work and resources to provide a comprehensive resource that informs stakeholders of conservation priorities based on global and local threat assessment, and national species responsibility.

## Software

The priority species list is generated using R statistical software (R Core Team, 2023) and the package `tidyverse` (Wickham et al., 2019) primarily. Other specific package details are provided throughout the following methods sections where relevant.

## Inclusion Criteria

Globally threatened species are here defined as species classified as Near Threatened, Vulnerable, Endangered, or Critically Endangered by the IUCN (IUCN, 2026) as of 2026. Nationally or by Belize's 2020 or 2025 national threat assessments (Belize Forest Department, 2025; Belize Forest Department Wildlife Programme, 2020).

National Responsibility Species (NRS) are species in which the contribution of the national population to global survival of the species is appreciable (Kukkala et al., 2019). NRS in Belize are here defined as species in which the percentage of its range in Belize (range share) is calculated as 20% or greater.

A specific species qualifies for the priority species list if it meets **any** of the following criteria:

| CRITERION 1 | CRITERION 2 | CRITERION 3 |
|---|---|---|
| **Globally Threatened** | **Nationally Threatened** | **National Responsibility** |
| Is a Belizean species classified **on the IUCN Red List** as category Critically Endangered, Endangered, Vulnerable, or Near Threatened. | Is a species listed on Belize's 2020 or 2025 **national threat assessments**. | Has an estimated **global range share** in Belize of 20% or greater. |

The species must also be in one of the focus taxa, which include mammals, birds, reptiles, amphibians, sharks and rays, bony fish, insects, mollusks, corals, fungi, and plants. The list of candidate species to test against these criteria is acquired from Fishbase for fish (retrieved 2026) (Froese & Pauly, 2026), and from IUCN-assessed species for all other taxa (retrieved 2026) (IUCN, 2026).

## Data Sources

1. National IUCN Red List for Threatened Avian Species - Belize (Belize Forest Department Wildlife Programme, 2020)
2. Belize National Red List of Threatened Species: Mammals, Birds, Reptiles and Amphibians (Belize Forest Department, 2025)
3. The full Belize country assessment from the IUCN redlist (IUCN, 2026), fetched into R using the `rredlist` package in 2026 (Gearty & Chamberlain, 2025).
4. The full list of Belizean bony fish species from Fishbase (Froese & Pauly, 2026), fetched into R using the `rfishbase` package in 2026 (Boettiger et al., 2012).
5. BirdLife range maps (BirdLife International and Handbook of the Birds of the World, 2025), manually downloaded and loaded into R in 2026.
6. Global Biodiversity Information Facility (GBIF) species occurrence records (GBIF.org User, 2026) fetched into R using the `rgbif` package in 2026 (Chamberlain et al., 2026).
7. Belize boundaries, including a union of mainland political boundaries and maritime jurisdiction (territorial sea and Exclusive Economic Zone) (ArcGIS_DemoBz, 2023b, 2023a; Meerman, 2013).

## Range Share Calculations

The percent of range share for a species in Belize is calculated to ensure species not on the redlist, but with near-endemism in Belize, are captured. Global range is calculated using points on GBIF, with the geometry being drawn as alpha hulls, which are shown to have reduced bias for calculating species' range extents as opposed to convex hulls (Burgman & Fox, 2003; Meyer et al., 2017; Valencia-Rodríguez et al., 2025). Where populations are heavily clustered, the alpha hull approach allows for multiple disjoint polygons to be used to represent a single species range. All projections used are equal-area, for consistency.

**GBIF Calculation - All Taxa:**

1. A sample of up to 5,000 occurrence records, as availability allows, is pulled from GBIF using the `rgbif` package (Chamberlain et al., 2026), function `occ_data()`. Occurrence records lacking coordinates or that have their coordinates flagged as suspicious by GBIF are not included.
2. The `rangeBuilder::getDynamicAlphaHull(initialAlpha = 3, fraction = 0.95)` function, which internally calls `alphahull::ahull()`, is used to search upward from 3 for the smallest whole number alpha with a resulting shape which contains ≥95% of points and has no more than 3 disjoint pieces of clustered points (Davis Rabosky et al., 2016; Pateiro-Lopez & Rodriguez-Casal, 2022).
   - Points not included in the resulting shape are dropped as outliers by the function.
   - The function automatically buffers by 10 km in Equal Earth projection, absorbing coordinate imprecision.
   - Using an alpha cap of 400, if no suitable value is found, the function falls back to a plain convex hull geometry for the species range.
   - For amphibians, fungi, and insects, oceans are clipped out. For corals, sharks, and rays, land is clipped out. For birds, mammals, mollusks, plants, and reptiles, no clipping occurs. Clipping for fish is determined by FishBase's internal habitat tagging system, which tags fish as freshwater, brackish, and/or saltwater. For freshwater-exclusive fish, oceans are clipped out. For saltwater-exclusive fish, land is clipped out. Clipping was done using `rnaturalearth` (Massicotte & South, 2026).

   This result is considered the global range for the species.
3. Self-intersections are cleaned from this range using the package `sf` (Pebesma & Bivand, 2023). The final area is calculated using Mollweide projection (Budic et al., 2016) for both the whole range and its intersection with the Belize boundary.
4. Range share (R) is calculated as:

```
R = area(global range ∩ Belize boundary) / area(global range)
```

**BirdLife Calculation - Only Birds:**

1. The corresponding BirdLife range map (BirdLife International and Handbook of the Birds of the World, 2025) forms the estimated global range. The final area is calculated using Mollweide projection (Budic et al., 2016) for both the whole range and its intersection with the Belize boundary.
2. Range share (R) is calculated as:

```
R = area(global range ∩ Belize boundary) / area(global range)
```

## Known Limitations

1. Taxonomic coverage is limited to the focus taxa species assessed by the IUCN or nationally in Belize.
2. Range share calculations (weight calculations) are estimations dependent on the most recent 5,000 occurrences on GBIF, which may be subject to bias.
3. Ranges are formed using all data on GBIF, meaning that if the range has changed over time, old range area will be included as well as new. For example, in the case of *Dermatemys mawii*, weight is less than 20%, and this may be due to all the old range in Mexico that has since disappeared from being included. In this way, the 5,000 fetch max is actually helpful, as recent uploads are used as opposed to historic ones. An analysis with a date range cutoff could serve as a validation followup or replacement for this approach.
4. The alpha hull method sometimes fails to construct a valid range polygon. This may occur if the number of points are too small to construct a polygon, in which case the species is data deficient. This may also be due to a numerical edge case in the R package's algorithm. Basically, when reconstructing the range boundary from the alpha shape, rounding collapses multiple points to the same coordinate, producing an invalid polygon. Of the final priority list species, 9 are affected. In future updates of this document, finding a solution to this computational problem should be a priority to reduce missing values.
5. Habitat clipping is not done in this methodology, apart from broad marine and terrestrial clipping, meaning the shape is drawn across habitats even if the species cannot live in those habitats
6. The pet trade is not excluded, as there is no systematic way to know if GBIF observations are captive across the board

## Literature Cited

ArcGIS_DemoBz. (2023a). *Belize_Country [Feature layer]* [Dataset]. ArcGIS Online. https://www.arcgis.com/home/item.html?id=09608485ef21491d9ea15a9a5f83fe20

ArcGIS_DemoBz. (2023b). *Belize_Nationalwaters [Feature layer]* [Dataset]. ArcGIS Online.

Belize Forest Department. (2025). *Belize National Red List of Threatened Species: Mammals, Birds, Reptiles and Amphibians*.

Belize Forest Department Wildlife Programme. (2020). *National IUCN Red List for Threatened Avian Species—Belize*.

BirdLife International and Handbook of the Birds of the World. (2025). *Bird species distribution maps of the world* (Version 2025.2) [Dataset]. http://datazone.birdlife.org/species/requestdis

Boettiger, C., Lang, D. T., & Wainwright, P. C. (2012). rfishbase: Exploring, manipulating and visualizing FishBase data from R. *Journal of Fish Biology*, *81*(6), 2030–2039. https://doi.org/10.1111/j.1095-8649.2012.03464.x

Budic, L., Didenko, G., & Dormann, C. F. (2016). Squares of different sizes: Effect of geographical projection on model parameter estimates in species distribution modeling. *Ecology and Evolution*, *6*(1), 202–211. https://doi.org/10.1002/ece3.1838

Burgman, M. A., & Fox, J. C. (2003). Bias in species range estimates from minimum convex polygons: Implications for conservation and options for improved planning. *Animal Conservation*, *6*(1), 19–28. https://doi.org/10.1017/S1367943003003044

Chamberlain, S., Barve, V., Mcglinn, D., Oldoni, D., Desmet, P., Geffert, L., & Ram, K. (2026). *rgbif: Interface to the Global Biodiversity Information Facility API* (R Package Version 3.8.4) [Computer software]. https://CRAN.R-project.org/package=rgbif

Davis Rabosky, A. R., Cox, C. L., Rabosky, D. L., Title, P. O., Holmes, I. A., Feldman, A., & McGuire, J. A. (2016). Coral snakes predict the evolution of mimicry across New World snakes. *Nature Communications*, *7*(1), 11484. https://doi.org/10.1038/ncomms11484

Froese, R., & Pauly, D. (2026). *FishBase* [Dataset]. www.fishbase.org

GBIF.org User. (2026). *Occurrence Download* (p. 103057944356) [Text/tab-separated-values,application/zip]. The Global Biodiversity Information Facility. https://doi.org/10.15468/DL.4KD3TT

Gearty, W., & Chamberlain, S. (2025). *rredlist: "IUCN" Red List Client* (p. 1.1.1) [Dataset]. https://doi.org/10.32614/CRAN.package.rredlist

IUCN. (2026). *The IUCN Red List of Threatened Species* (Version 2026-1) [Computer software]. https://www.iucnredlist.org

Kukkala, A., Maiorano, L., Thuiller, W., & Arponen, A. (2019). Identifying national responsibility species based on spatial conservation prioritization. *Biological Conservation*, *236*, 411–419. https://doi.org/10.1016/j.biocon.2019.05.046

Massicotte, P., & South, A. (2026). *rnaturalearth: World Map Data from Natural Earth* (R Package Version 1.2.0) [Computer software]. https://CRAN.R-project.org/package=rnaturalearth

Meerman, J. C. (2013). *Belize Basemap* [Dataset]. Biodiversity and Environmental Resource Data System of Belize. http://www.biodiversity.bz/

Meyer, L., Diniz-Filho, J. A. F., & Lohmann, L. G. (2017). A comparison of hull methods for estimating species ranges and richness maps. *Plant Ecology & Diversity*, *10*(5–6), 389–401. https://doi.org/10.1080/17550874.2018.1425505

Pateiro-Lopez, B., & Rodriguez-Casal, A. (2022). *alphahull: Generalization of the Convex Hull of a Sample of Points in the Plane* (R Package Version 2.5) [Computer software]. https://CRAN.R-project.org/package=alphahull

Pebesma, E., & Bivand, R. (2023). *Spatial Data Science: With Applications in R* (1st ed.). Chapman and Hall/CRC. https://doi.org/10.1201/9780429459016

R Core Team. (2023). *R: A Language and Environment for Statistical Computing* (R Version 4.3.2) [Computer software]. R Foundation for Statistical Computing. https://www.R-project.org

Valencia-Rodríguez, D., Villalobos, F., Tedesco, P. A., Mercado-Silva, N., Rubio-Godoy, M., & Rojas-Soto, O. (2025). Comparing Methods for Estimating Geographic Ranges in Freshwater Fishes: Several Mirrors of the Same Reality. *Freshwater Biology*, *70*(3), e70014. https://doi.org/10.1111/fwb.70014

Wickham, H., Averick, M., Bryan, J., Chang, W., McGowan, L., François, R., Grolemund, G., Hayes, A., Henry, L., Hester, J., Kuhn, M., Pedersen, T., Miller, E., Bache, S., Müller, K., Ooms, J., Robinson, D., Seidel, D., Spinu, V., … Yutani, H. (2019). Welcome to the Tidyverse. *Journal of Open Source Software*, *4*(43), 1686. https://doi.org/10.21105/joss.01686
