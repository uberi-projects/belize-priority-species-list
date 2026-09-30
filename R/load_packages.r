# load_packages.r

## Check Required Packages ------------------------
options(repos = c(CRAN = "https://cran.rstudio.com/"))
required_packages <- c(
    "sf", "rgbif", "rredlist", "taxize", "rfishbase", "rangeBuilder", "alphahull", "units",
    "dplyr", "tidyr", "purrr"
)
install_if_missing <- function(package) {
    if (!requireNamespace(package, quietly = TRUE)) {
        install.packages(package)
    }
}
invisible(lapply(required_packages, install_if_missing))

## Attach Packages ------------------------
library(sf)
library(rgbif)
library(rredlist)
library(taxize)
library(rfishbase)
library(rangeBuilder)
library(alphahull)
library(units)
library(dplyr)
library(tidyr)
library(purrr)
