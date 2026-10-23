# ---------------------------------------------------------------------------
# Rebuild assets/heatmap/heatmap.json from local git repositories.
#
# The Now page shows a GitHub-style heatmap of real commit activity. This
# script is what produces its data, so re-run it whenever you want the page
# refreshed:
#
#     Rscript tools/build_activity.R
#
# It reads only repositories listed in `repos` below, keeps only commits whose
# author matches `author_pattern`, and writes one entry per day. Repositories
# that are not on this machine are skipped with a warning rather than failing.
# ---------------------------------------------------------------------------

library(jsonlite)

home <- path.expand("~")

repos <- file.path(home, "Documents", c(
  "r/websites/EvolvoErgoSum",
  "r/websites/laughing-octo-spork",
  "r/cyclura carinata database app",
  "projects/transcriptomic/galapagos_iguanas",
  "data/ballisto/dati"
))

author_pattern <- "Colosimo"   # excludes upstream commits in vendored code

# Tooltip detail. FALSE (default) shows "<repo> x N", which is safe to publish
# without reading every commit message first. Set TRUE to show the messages
# themselves - but check them first: real history contains things you may not
# want on a professional page.
include_messages <- FALSE

window_days    <- 364          # 365 days inclusive of today
out_file       <- "assets/heatmap/heatmap.json"

end_date   <- Sys.Date()
start_date <- end_date - window_days

# ---- Collect commits -------------------------------------------------------
collect <- function(repo) {
  if (!dir.exists(file.path(repo, ".git"))) {
    warning("skipping (not a git repo here): ", repo, call. = FALSE)
    return(NULL)
  }
  out <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(repo), "log", "--all", "--no-merges",
      paste0("--since=", start_date),
      paste0("--author=", author_pattern),
      # %x09 is git's escape for a tab: a literal tab here would be split
      # by the shell when R assembles the command line.
      "--date=short", shQuote("--pretty=format:%ad%x09%s")),
    stdout = TRUE, stderr = FALSE
  ))
  if (length(out) == 0) return(NULL)
  parts <- strsplit(out, "\t", fixed = TRUE)
  parts <- parts[lengths(parts) == 2]
  if (length(parts) == 0) return(NULL)
  data.frame(
    date    = as.Date(vapply(parts, `[`, "", 1)),
    message = vapply(parts, `[`, "", 2),
    repo    = basename(repo),
    stringsAsFactors = FALSE
  )
}

commits <- do.call(rbind, lapply(repos, collect))
if (is.null(commits) || nrow(commits) == 0) {
  stop("no commits found - check the repo paths and author_pattern")
}
commits <- commits[commits$date >= start_date & commits$date <= end_date, ]

# ---- One entry per day, newest activity first ------------------------------
all_days <- seq(start_date, end_date, by = "day")

entries <- lapply(all_days, function(d) {
  rows <- commits[commits$date == d, , drop = FALSE]
  acts <- if (nrow(rows) == 0) list() else {
    lab <- if (include_messages) paste0(rows$repo, ": ", rows$message) else rows$repo
    tab <- as.data.frame(table(lab), stringsAsFactors = FALSE)
    names(tab) <- c("activity", "n")
    tab <- tab[order(-tab$n, tab$activity), ]
    unname(lapply(seq_len(nrow(tab)), function(i)
      list(activity = tab$activity[i], n = as.integer(tab$n[i]))))
  }
  list(date = format(d), activities = acts)
})

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
write_json(entries, out_file, auto_unbox = TRUE)

cat(sprintf("wrote %s\n  %d commits across %d repos\n  %s to %s\n",
            out_file, nrow(commits), length(unique(commits$repo)),
            start_date, end_date))
