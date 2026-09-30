# setup.r

# Setup Packages -----------------------------------------
required_packages <- c(
    "sf", "rgbif", "rredlist", "taxize", "rfishbase", "rangeBuilder", "alphahull", "units",
    "dplyr", "tidyr", "purrr"
)
if (requireNamespace("renv", quietly = TRUE) && file.exists("renv.lock")) {
    message("renv.lock found - restoring pinned package versions via renv::restore()...")
    renv::restore()
} else {
    message("No renv.lock found (or renv not installed) - falling back to a plain install of the ",
        "required packages. Versions will not be pinned; see README.md if you want reproducible ",
        "versions via renv instead.")
    missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
    if (length(missing) > 0) {
        message("Installing: ", paste(missing, collapse = ", "))
        install.packages(missing, repos = "https://cloud.r-project.org")
    } else {
        message("All required packages already installed.")
    }
}