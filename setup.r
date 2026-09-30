# setup.r
#
# One-time environment setup for this project. Run this before anything else.
#
# Run manually:
#   Rscript setup.r
# or, from within an R session in this project directory:
#   source("setup.r")

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

message("\nNext steps:")
message("1. Copy .Renviron.example to .Renviron and fill in your real credentials.")
message("2. (Optional, for the BirdLife comparison columns) See birdlife_ranges/README.md.")
message("3. Run run_pipeline.r.")
