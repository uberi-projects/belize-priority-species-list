# spatial_weight_functions.r

## Drop interior rings (holes) from a polygon layer ------------------------
drop_holes <- function(x) {
    st_sfc(lapply(st_geometry(x), function(g) {
        if (inherits(g, "MULTIPOLYGON")) {
            st_multipolygon(lapply(unclass(g), function(p) list(p[[1]])))
        } else if (inherits(g, "POLYGON")) {
            st_polygon(list(g[[1]]))
        } else {
            g
        }
    }), crs = st_crs(x))
}

## Read Belize's land area (mainland + cayes) and declared maritime jurisdiction ------------------------
belize_land_district <- st_read("basemap/Belize_Basemap.shp", quiet = TRUE) %>%
    st_transform(4326) %>%
    st_make_valid() %>%
    drop_holes()
belize_land_national <- st_read("basemap/land_belize.txt", quiet = TRUE) %>%
    st_transform(4326) %>%
    st_make_valid() %>%
    drop_holes()
belize_maritime <- st_read("basemap/maritime_belize.txt", quiet = TRUE) %>%
    st_transform(4326) %>%
    st_make_valid()

## Merge every source into a single boundary for intersection ------------------------
belize_boundary <- st_union(c(belize_land_district, belize_land_national, st_geometry(belize_maritime)))

## Equal-area projection for accurate area calculations ------------------------
mollweide_crs <- "+proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"