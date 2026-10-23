# ---------------------------------------------------------------------------
# Build assets/heatmap/heatmap.json from data/activity_log.csv.
#
#     Rscript tools/build_leisure.R
#
# One row per thing per day; rows with an `until` date count on every day in
# the range. Lines starting with # in the CSV are ignored.
# ---------------------------------------------------------------------------

library(jsonlite)

in_file     <- "data/activity_log.csv"
out_file    <- "assets/heatmap/heatmap.json"
window_days <- 364                      # 365 days, inclusive of today

end_date   <- Sys.Date()
start_date <- end_date - window_days
all_days   <- seq(start_date, end_date, by = "day")

# ---- Read, skipping comment lines -----------------------------------------
lines <- readLines(in_file, warn = FALSE)
lines <- lines[!grepl("^\\s*#", lines)]
lines <- lines[nzchar(trimws(lines))]

log <- if (length(lines) <= 1) {
  data.frame(date = character(), until = character(), category = character(),
             title = character(), note = character(), stringsAsFactors = FALSE)
} else {
  read.csv(text = paste(lines, collapse = "\n"), stringsAsFactors = FALSE,
           colClasses = "character")
}

for (col in c("date", "until", "category", "title", "note")) {
  if (is.null(log[[col]])) log[[col]] <- rep("", nrow(log))
  log[[col]] <- trimws(ifelse(is.na(log[[col]]), "", log[[col]]))
}

# ---- Expand each row over its date range -----------------------------------
expand_row <- function(i) {
  from <- suppressWarnings(as.Date(log$date[i]))
  if (is.na(from)) {
    warning("row ", i, ": unreadable date '", log$date[i], "' - skipped", call. = FALSE)
    return(NULL)
  }
  to <- if (nzchar(log$until[i])) suppressWarnings(as.Date(log$until[i])) else from
  if (is.na(to) || to < from) to <- from
  label <- paste0(
    if (nzchar(log$category[i])) paste0(log$category[i], ": ") else "",
    log$title[i],
    if (nzchar(log$note[i])) paste0(" (", log$note[i], ")") else ""
  )
  data.frame(date = seq(from, to, by = "day"), label = label,
             stringsAsFactors = FALSE)
}

rows <- if (nrow(log) == 0) NULL else do.call(rbind, lapply(seq_len(nrow(log)), expand_row))

n_kept <- 0L
if (!is.null(rows)) {
  rows   <- rows[rows$date >= start_date & rows$date <= end_date, , drop = FALSE]
  n_kept <- nrow(rows)
}

# ---- One entry per day ------------------------------------------------------
entries <- lapply(all_days, function(d) {
  acts <- list()
  if (n_kept > 0) {
    these <- rows$label[rows$date == d]
    if (length(these)) {
      tab <- as.data.frame(table(these), stringsAsFactors = FALSE)
      names(tab) <- c("activity", "n")
      tab  <- tab[order(-tab$n, tab$activity), ]
      acts <- unname(lapply(seq_len(nrow(tab)), function(i)
        list(activity = tab$activity[i], n = as.integer(tab$n[i]))))
    }
  }
  list(date = format(d), activities = acts)
})

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
write_json(entries, out_file, auto_unbox = TRUE)

active <- sum(vapply(entries, function(e) length(e$activities) > 0, logical(1)))
cat(sprintf("wrote %s\n  %d entries on %d days (%s to %s)\n",
            out_file, n_kept, active, start_date, end_date))
if (n_kept == 0)
  cat("  note: the log is empty - add rows to ", in_file, "\n", sep = "")
