# Elicit FHHS Pedigree API
#
# This Plumber API provides endpoints for generating family pedigree diagrams
# from structured data files. It uses the Pedixplorer package to create visual
# representations of family trees with cancer diagnosis information.

library(plumber)
library(Pedixplorer)

#* @apiTitle Elicit FHHS Pedixplorer API
#* @apiDescription Elicit FHHS pedigree rendering with Pedixplorer

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

normalize_flag <- function(value, default = FALSE) {
  normalized <- tolower(trimws(as.character(value)))
  result <- rep(default, length(normalized))
  result[normalized %in% c("1", "true", "t", "yes", "y")] <- TRUE
  result[normalized %in% c("0", "false", "f", "no", "n")] <- FALSE
  result[normalized %in% c("", "na", "n/a", "null")] <- default
  result
}

build_pedixplorer_df <- function(data_df) {
  names(data_df) <- tolower(names(data_df))

  has_legacy_quadrants <- all(c("ul", "ur", "ll", "lr") %in% names(data_df))

  famid <- if ("famid" %in% names(data_df)) {
    normalize_text(data_df$famid)
  } else if ("ped" %in% names(data_df)) {
    normalize_text(data_df$ped)
  } else {
    rep("1", nrow(data_df))
  }

  id <- normalize_text(data_df$id)
  dadid <- if ("dadid" %in% names(data_df)) normalize_parent_id(data_df$dadid) else rep(NA_character_, nrow(data_df))
  momid <- if ("momid" %in% names(data_df)) normalize_parent_id(data_df$momid) else rep(NA_character_, nrow(data_df))
  sex <- suppressWarnings(as.integer(data_df$sex))
  sex[is.na(sex)] <- 3L

  proband <- if ("proband" %in% names(data_df)) {
    normalize_flag(data_df$proband)
  } else {
    id == "7"
  }

  affection <- if ("affection" %in% names(data_df)) {
    normalize_flag(data_df$affection)
  } else if (has_legacy_quadrants) {
    rowSums(data_df[, c("ul", "ur", "ll", "lr")], na.rm = TRUE) > 0
  } else {
    rep(FALSE, nrow(data_df))
  }

  deceased <- if ("deceased" %in% names(data_df)) {
    normalize_flag(data_df$deceased)
  } else if ("status" %in% names(data_df)) {
    trimws(as.character(data_df$status)) %in% c("1", "deceased", "DECEASED")
  } else {
    rep(FALSE, nrow(data_df))
  }

  display_id <- if ("display_id" %in% names(data_df)) {
    normalize_text(data_df$display_id)
  } else if ("label" %in% names(data_df)) {
    normalize_text(gsub("_", " ", data_df$label))
  } else {
    id
  }

  cancer_label <- if ("cancer_label" %in% names(data_df)) {
    normalize_text(data_df$cancer_label)
  } else {
    rep("", nrow(data_df))
  }

  data.frame(
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
}

#* Generates a pedigree SVG image from a pedigree data frame
#*
#* This endpoint accepts a tab-delimited file containing pedigree data and
#* generates an SVG visualization of the family tree. The expected input is a
#* simplified pedigree table with one affected flag, one proband flag, a display
#* label, and a cancer label for each individual.
#*
#* @post /svg
#* @param ped:file A tab-delimited file containing pedigree data
#* @serializer svg
function(ped) {
  file_content <- ped[[1]]

  data_df <- read.table(
    text = file_content,
    header = TRUE,
    sep = "\t",
    na.strings = "NA",
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  pedigree_df <- build_pedixplorer_df(data_df)

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

  par(mar = c(5, 2, 1, 2))

  suppressWarnings(
    plot(
      pedigree_obj,
      aff_mark = FALSE,
      id_lab = "display_id",
      label = "cancer_label",
      symbolsize = 1.2,
      cex = 0.7,
      legend = FALSE
    )
  )

  mtext("P with arrow = Respondent", side = 1, line = 2, cex = 0.8, col = "black")
  mtext("Red fill = Family member with cancer", side = 1, line = 3, cex = 0.8, col = "red")

  if (grepl("*", file_content, fixed = TRUE)) {
    mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 4, cex = 0.8, col = "black")
  }
}

#* Health check endpoint
#*
#* Returns a simple status object to verify the API is running and responsive.
#*
#* @get /healthz
function() {
  list(status = "ok")
}