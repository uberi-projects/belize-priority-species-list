# retry_gbif_fetch_failures_loop.r

## Setup ------------------------
groups <- c("reptiles", "fungi", "amphibians", "mollusks", "corals", "sharks_rays", "mammals", "insects", "birds", "fish", "plants")
count_fetch_failed <- function() {
    sum(sapply(groups, function(g) {
        d <- read.csv(file.path("outputs/results/primary/by_group_all", paste0(g, ".csv")), colClasses = c(gbif_id = "character"))
        sum(d$note == "GBIF fetch failed after retries", na.rm = TRUE)
    }))
}

## Loop Retry Rounds ------------------------
max_retry_rounds <- 10
retry_round <- 1
repeat {
    n_failed <- count_fetch_failed()
    if (n_failed == 0) {
        message(if (retry_round == 1) "No transient GBIF fetch failures to retry." else "No GBIF fetch failures remain.")
        break
    }
    message(paste0("Retry round ", retry_round, ": ", n_failed, " species flagged as GBIF fetch failed - retrying..."))
    fetch_failed <- bind_rows(lapply(groups, function(g) {
        read.csv(file.path("outputs/results/primary/by_group_all", paste0(g, ".csv")), colClasses = c(gbif_id = "character")) %>%
            filter(note == "GBIF fetch failed after retries") %>%
            transmute(gbif_id, species, clip, taxon = g)
    }))
    if (!dir.exists("outputs/intermediates/primary/by_group")) dir.create("outputs/intermediates/primary/by_group", recursive = TRUE)
    saveRDS(fetch_failed, "outputs/intermediates/primary/by_group/fetch_failed_for_retry.rds")
    system2("Rscript", c("R/retry_gbif_fetch_failures.r", "1", "1"))
    source("R/merge_fetch_retry_results.r")
    n_failed_after <- count_fetch_failed()
    message(paste0("Retry round ", retry_round, " result: ", n_failed - n_failed_after, " recovered, ", n_failed_after, " still failed."))
    if (n_failed_after == 0) break
    # Zero progress means the rest are permanent failures (e.g. no usable GBIF data at all). Stop rather than loop forever.
    if (n_failed_after >= n_failed) {
        message("No progress this round. Stopping.")
        break
    }
    retry_round <- retry_round + 1
    if (retry_round > max_retry_rounds) {
        message(paste0("Reached max_retry_rounds (", max_retry_rounds, ") - stopping with ", n_failed_after, " species still failed."))
        break
    }
}