# submit_gbif_citation_download.r

## Setup ------------------------
suppressMessages(library(rgbif))

## Load Taxon Keys ------------------------
keys <- readRDS("outputs/gbif_download_taxon_keys.rds")
message(paste0("Submitting download for ", length(keys), " taxon keys..."))

## Submit Download ------------------------
# Credentials read from GBIF_USER/GBIF_PWD/GBIF_EMAIL (.Renviron) - never hardcoded or printed.
download_key <- occ_download(
    pred_in("taxonKey", keys),
    pred("hasCoordinate", TRUE),
    pred("hasGeospatialIssue", FALSE),
    format = "SIMPLE_CSV",
    user = Sys.getenv("GBIF_USER"),
    pwd = Sys.getenv("GBIF_PWD"),
    email = Sys.getenv("GBIF_EMAIL")
)

## Save Download Key ------------------------
message(paste0("Download submitted. Key: ", download_key))
saveRDS(as.character(download_key), "outputs/gbif_citation_download_key.rds")
message("Saved download key to outputs/gbif_citation_download_key.rds")
message("Check status with occ_download_meta() or on gbif.org - processing can take minutes to hours.")
