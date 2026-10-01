# submit_gbif_citation_download.r

## Setup ------------------------
suppressMessages(library(rgbif))

## Load Taxon Keys ------------------------
keys <- readRDS("outputs/results/citation/gbif_download_taxon_keys.rds")
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
saveRDS(as.character(download_key), "outputs/results/citation/gbif_citation_download_key.rds")
message("Saved download key to outputs/results/citation/gbif_citation_download_key.rds")

## Poll Until Complete ------------------------
terminal_statuses <- c("SUCCEEDED", "KILLED", "FAILED", "CANCELLED")
repeat {
    status <- occ_download_meta(download_key)$status
    message(paste0("  Status: ", status))
    if (status %in% terminal_statuses) break
    Sys.sleep(90)
}
message(paste0(
    "Download finished with status: ", status,
    ". DOI/details at https://www.gbif.org/occurrence/download/", download_key
))
