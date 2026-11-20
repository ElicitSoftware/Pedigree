# Elicit FHHS Pedigree API
#
# This Plumber API provides endpoints for generating family pedigree diagrams
# from structured data files. It uses the Pedixplorer package to create visual
# representations of family trees with cancer diagnosis information.

library(plumber)
library(Pedixplorer)

#* @apiTitle Elicit FHHS Pedixplorer API
#* @apiDescription Elicit FHHS pedigree rendering with Pedixplorer

# A pedigree file is a few kilobytes. A request body over this many bytes is refused with
# 413 (plumber 1.1.0 or later; ci/smoke.sh checks that the installed plumber honors it).
options(plumber.maxRequestSize = 1e6)

# The most people one pedigree may have; a larger one is refused with 413 before it is laid out.
# A family history is a few dozen people at most.
max_pedigree_rows <- 500L

# The image's version, from the build (Dockerfile ARG VERSION); "dev" for a local build.
pedigree_version <- Sys.getenv("PEDIGREE_VERSION", unset = "dev")

# The service token: the value a caller presents as "Authorization: Bearer <token>".
# It is read once, here, and removed from the environment; it is never printed.
service_token_variable <- "ELICIT_SERVICE_TOKEN"
service_token_min_length <- 32L
service_token <- trimws(Sys.getenv(service_token_variable, unset = ""))
Sys.unsetenv(service_token_variable)

service_token_length <- nchar(service_token, type = "chars", allowNA = TRUE)
if (nzchar(service_token) && (is.na(service_token_length) || service_token_length < service_token_min_length)) {
  # Names the variable and the length required, never the value or its length
  stop(
    service_token_variable, " must be at least ", service_token_min_length,
    " characters long; refusing to start.",
    call. = FALSE
  )
}
if (!nzchar(service_token)) {
  message(
    "WARNING: ", service_token_variable, " is not set; every request except /healthz ",
    "is answered with 503 until it is."
  )
}

# R has no constant-time comparison, and == stops at the first differing byte. Both values
# are therefore reduced to HMAC-SHA-256 digests under a key drawn once per process, and the
# digests are compared over their whole length.
service_token_compare_key <- sodium::random(32)

service_token_digest <- function(value) {
  sodium::sha256(charToRaw(enc2utf8(value)), key = service_token_compare_key)
}

service_token_matches <- function(presented) {
  difference <- xor(service_token_digest(presented), service_token_digest(service_token))
  sum(as.integer(difference)) == 0L
}

# The token of an "Authorization: Bearer <token>" header, or NULL for anything else
bearer_token <- function(header) {
  if (is.null(header) || length(header) != 1L || is.na(header)) {
    return(NULL)
  }
  match <- regmatches(header, regexec("^[Bb][Ee][Aa][Rr][Ee][Rr] +([^ ]+) *$", header))[[1]]
  if (length(match) == 2L) match[2] else NULL
}

#* Requires the service token on every path except /healthz
#*
#* A route added later is protected unless it is named here. Without a configured token
#* nothing is served (503); a missing, malformed or wrong credential is answered the same
#* way (401), so a caller cannot tell them apart.
#*
#* @filter service_token
function(req, res) {
  if (identical(req$PATH_INFO, "/healthz")) {
    return(plumber::forward())
  }

  if (!nzchar(service_token)) {
    res$status <- 503
    res$setHeader("Content-Type", "application/json")
    res$body <- '{"error":"service token not configured"}'
    return(res)
  }

  presented <- bearer_token(req$HTTP_AUTHORIZATION)
  if (is.null(presented) || !service_token_matches(presented)) {
    res$status <- 401
    res$setHeader("WWW-Authenticate", "Bearer")
    res$body <- ""
    return(res)
  }

  plumber::forward()
}

normalize_parent_id <- function(value) {
  normalized <- trimws(as.character(value))
  normalized[normalized %in% c("", "0", "NA", "N/A", "null", "NULL")] <- NA_character_
  normalized
}

normalize_text <- function(value) {
  normalized <- as.character(value)
  normalized[is.na(normalized)] <- ""
  gsub("[\t\r\n]+", " ", normalized)
}

wrap_cancer_label <- function(text, width = 26) {
  vapply(text, function(x) {
    if (is.na(x) || !nzchar(trimws(x))) return(x)
    entries <- trimws(strsplit(x, ";")[[1]])
    entries <- entries[nzchar(entries)]
    lines <- character(0)
    current <- ""
    for (entry in entries) {
      candidate <- if (nzchar(current)) paste(current, entry, sep = "; ") else entry
      if (nzchar(current) && nchar(candidate) > width) {
        lines <- c(lines, current)
        current <- entry
      } else {
        current <- candidate
      }
    }
    if (nzchar(current)) lines <- c(lines, current)
    paste(lines, collapse = "\n")
  }, FUN.VALUE = character(1), USE.NAMES = FALSE)
}

compute_layout_scale <- function(id, dadid, momid, comfortable_width = 4, min_scale = 0.45) {
  n <- length(id)
  if (n <= comfortable_width) {
    return(1)
  }

  dadid_k <- ifelse(is.na(dadid), "0", dadid)
  momid_k <- ifelse(is.na(momid), "0", momid)

  depth <- tryCatch(
    suppressWarnings(kindepth(id, dadid_k, momid_k)),
    error = function(e) rep(0, n)
  )

  max_gen_width <- max(table(depth))
  if (max_gen_width <= comfortable_width) {
    return(1)
  }

  max(min_scale, comfortable_width / max_gen_width)
}

normalize_flag <- function(value, default = FALSE) {
  normalized <- tolower(trimws(as.character(value)))
  result <- rep(default, length(normalized))
  result[normalized %in% c("1", "true", "t", "yes", "y")] <- TRUE
  result[normalized %in% c("0", "false", "f", "no", "n")] <- FALSE
  result[normalized %in% c("", "na", "n/a", "null")] <- default
  result
}

add_proband_halo <- function(plot_data, pedigree_df, layout_scale = 1) {
  proband_rows <- pedigree_df[pedigree_df$proband, , drop = FALSE]

  if (nrow(proband_rows) == 0) {
    return(plot_data)
  }

  proband_row <- proband_rows[1, , drop = FALSE]
  halo_color <- "#33a33b"
  boxh <- plot_data$par_usr$boxh

  node_rows <- plot_data$df[
    plot_data$df$id == "polygon" & grepl(proband_row$display_id, plot_data$df$tips, fixed = TRUE),
    ,
    drop = FALSE
  ]

  if (nrow(node_rows) == 0) {
    return(plot_data)
  }

  proband_shape <- if (proband_row$sex == 1L) 0 else if (proband_row$sex == 2L) 1 else 5
  halo_cex <- (if (proband_row$sex == 2L) 5 else 6) * layout_scale

  if (!"pch" %in% names(plot_data$df)) {
    plot_data$df$pch <- NA_real_
  }

  halo_row <- data.frame(
    id = "proband_halo",
    x0 = node_rows$x0[1],
    y0 = node_rows$y0[1] + (boxh / 2),
    x1 = NA_real_,
    y1 = NA_real_,
    type = "points",
    fill = halo_color,
    border = NA_character_,
    angle = NA_real_,
    density = NA_real_,
    cex = halo_cex,
    label = NA_character_,
    tips = "",
    lwd = 5,
    adjx = NA_real_,
    adjy = NA_real_,
    lty = NA_real_,
    pch = proband_shape,
    stringsAsFactors = FALSE
  )

  plot_data$df <- rbind(halo_row, plot_data$df)
  plot_data
}

build_pedixplorer_df <- function(data_df) {
  names(data_df) <- tolower(names(data_df))
  # Columns are read with [[ ]], which matches a column name exactly ($ would also accept a prefix)

  has_legacy_quadrants <- all(c("ul", "ur", "ll", "lr") %in% names(data_df))

  famid <- if ("famid" %in% names(data_df)) {
    normalize_text(data_df[["famid"]])
  } else if ("ped" %in% names(data_df)) {
    normalize_text(data_df[["ped"]])
  } else {
    rep("1", nrow(data_df))
  }

  id <- normalize_text(data_df[["id"]])
  dadid <- if ("dadid" %in% names(data_df)) normalize_parent_id(data_df[["dadid"]]) else rep(NA_character_, nrow(data_df))
  momid <- if ("momid" %in% names(data_df)) normalize_parent_id(data_df[["momid"]]) else rep(NA_character_, nrow(data_df))
  sex <- suppressWarnings(as.integer(data_df[["sex"]]))
  sex[is.na(sex)] <- 3L

  # The legacy layout (ped1.txt, the README's sample) has no proband column. FHHS numbers the
  # proband 7 in every file it sends (FamilyMember.PROBAND_ID), so that is the fallback.
  proband <- if ("proband" %in% names(data_df)) {
    normalize_flag(data_df[["proband"]])
  } else {
    id == "7"
  }

  affection <- if ("affection" %in% names(data_df)) {
    normalize_flag(data_df[["affection"]])
  } else if (has_legacy_quadrants) {
    rowSums(data_df[, c("ul", "ur", "ll", "lr")], na.rm = TRUE) > 0
  } else {
    rep(FALSE, nrow(data_df))
  }

  deceased <- if ("deceased" %in% names(data_df)) {
    normalize_flag(data_df[["deceased"]])
  } else if ("status" %in% names(data_df)) {
    trimws(as.character(data_df[["status"]])) %in% c("1", "deceased", "DECEASED")
  } else {
    rep(FALSE, nrow(data_df))
  }

  display_id <- if ("display_id" %in% names(data_df)) {
    normalize_text(data_df[["display_id"]])
  } else if ("label" %in% names(data_df)) {
    normalize_text(gsub("_", " ", data_df[["label"]]))
  } else {
    id
  }

  cancer_label <- if ("cancer_label" %in% names(data_df)) {
    normalize_text(data_df[["cancer_label"]])
  } else {
    rep("", nrow(data_df))
  }
  cancer_label <- wrap_cancer_label(cancer_label)

  result <- data.frame(
    famid = famid,
    id = id,
    dadid = dadid,
    momid = momid,
    sex = sex,
    deceased = deceased,
    proband = proband,
    affection = affection,
    avail = FALSE,
    display_id = display_id,
    cancer_label = cancer_label,
    stringsAsFactors = FALSE
  )

  # Large families get packed tighter horizontally by Pedixplorer's own
  # layout, but it does not shrink text/symbols to match - so scale those
  # down here in proportion to the widest generation to keep them legible.
  attr(result, "layout_scale") <- compute_layout_scale(id, dadid, momid)
  result
}

#* Generates a landscape SVG image from a pedigree data frame
#*
#* This endpoint accepts a tab-delimited file containing pedigree data and
#* generates an SVG visualization of the family tree in landscape orientation (11x8.5 inches).
#* The SVG is returned as a character string.
#*
#* @post /svg
#* @param ped:file A tab-delimited file containing pedigree data
#* @serializer contentType list(type="image/svg+xml")
function(ped, res) {
  # Requests are handled one at a time, so a device still open here was left by an earlier one
  graphics.off()

  # plumber hands a text/plain part over as text and any other part (application/octet-stream,
  # what curl sends for a file without a known extension) as raw bytes
  file_content <- ped[[1]]
  if (is.raw(file_content)) file_content <- rawToChar(file_content)

  data_df <- read.table(
    text = file_content,
    header = TRUE,
    sep = "\t",
    na.strings = "NA",
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  # Laying out a pedigree takes time that grows with its size, and requests are served one at
  # a time, so a pedigree over the limit is refused before any layout work (413, as for a body
  # over the size limit).
  if (nrow(data_df) > max_pedigree_rows) {
    res$status <- 413
    res$setHeader("Content-Type", "application/json")
    res$body <- sprintf('{"error":"a pedigree may have at most %d people"}', max_pedigree_rows)
    return(res)
  }

  pedigree_df <- build_pedixplorer_df(data_df)
  layout_scale <- attr(pedigree_df, "layout_scale")
  if (is.null(layout_scale)) layout_scale <- 1

  pedigree_obj <- suppressWarnings(
    Pedigree(
      pedigree_df,
      col_aff = "affection",
      col_avail = "avail",
      colors_aff = c("white", "red"),
      colors_unaff = c("white", "white"),
      colors_avail = c("black", "black")
    )
  )

  # Create a temporary file for the SVG
  svg_file <- tempfile(fileext = ".svg")
  svg(filename = svg_file, width = 11, height = 8.5)
  # Close this request's device and remove its file however the function exits
  dev_id <- dev.cur()
  on.exit({
    if (dev_id %in% dev.list()) dev.off(dev_id)
    unlink(svg_file)
  }, add = TRUE)
  # Room below for the legend lines, and at the sides so labels at the edges are not cut off
  par(mar = c(5, 4, 1, 4))

  plot_data <- suppressWarnings(
    ped_to_plotdf(
      pedigree_obj,
      aff_mark = FALSE,
      id_lab = "display_id",
      label = "cancer_label",
      label_dist = c(1, 1.5, 2.1),
      symbolsize = 1.2 * layout_scale,
      cex = 0.7 * layout_scale
    )
  )

  plot_data$df <- subset(plot_data$df, !(id %in% c("consultand-proband", "proband")))
  plot_data <- add_proband_halo(plot_data, pedigree_df, layout_scale)

  suppressWarnings(
    plot_fromdf(
      plot_data$df,
      usr = plot_data$par_usr$usr,
      boxw = plot_data$par_usr$boxw,
      boxh = plot_data$par_usr$boxh
    )
  )

  mtext("Red fill = Family member with cancer", side = 1, line = 2, cex = 0.8, col = "red")

  if (grepl("*", file_content, fixed = TRUE)) {
    mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 3, cex = 0.8, col = "black")
  }

  dev.off(dev_id)

  # Read SVG content and return
  svg_content <- paste(readLines(svg_file, warn = FALSE), collapse = "\n")
  return(svg_content)
}

#* Health check endpoint
#*
#* Returns a simple status object, with the image's version, to verify the API is running and
#* responsive.
#*
#* @get /healthz
function() {
  list(status = "ok", version = pedigree_version)
}