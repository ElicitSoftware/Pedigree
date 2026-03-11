# Elicit FHHS Pedigree API
#
# This Plumber API provides endpoints for generating family pedigree diagrams
# from structured data files. It uses the kinship2 package to create visual
# representations of family trees with cancer diagnosis information.
#
# Find out more about building APIs with Plumber here:
#    https://www.rplumber.io/
#

# Load required libraries for pedigree processing and visualization
library(plumber)    # REST API framework
library(Matrix)     # Matrix operations
library(quadprog)   # Quadratic programming (dependency for kinship2)
library(kinship2)   # Pedigree plotting and kinship calculations

#* @apiTitle Elicit FHHS Kinship API
#* @apiDescription Elicit FHHS Kinship Example

#* Generates a pedigree SVG image from a pedigree data frame
#* 
#* This endpoint accepts a tab-delimited file containing pedigree data and
#* generates an SVG visualization of the family tree. The input file should
#* include columns for: ID, Dadid, Momid, Sex, Status, Label, Ped, and
#* affected status indicators (ul, ur, ll, lr representing quadrants for
#* multiple cancer types).
#*
#* @post /svg
#* @param ped:file A tab-delimited file containing pedigree data
#* @serializer svg
function(ped) {
  # Extract the file content from the uploaded file object
  # The ped parameter is a list where ped[[1]] contains the actual content
  file_content <- ped[[1]]

  # Parse the tab-delimited file content into a data frame
  # Expected columns: ID, Dadid, Momid, Sex, Status, Label, Ped, ul, ur, ll, lr
  data_df <- read.table(
    text = file_content,
    header = TRUE,
    sep = "\t",
    na.strings = "NA",
    stringsAsFactors = FALSE
  )
  
  # Create affected status matrix for kinship2
  # The four columns (UL, UR, LL, LR) represent quadrants of the pedigree symbol
  # allowing visualization of up to 4 different cancer types per individual
  aff <- data.frame(UL=data_df$ul, UR=data_df$ur, LL=data_df$ll, lr=data_df$lr)
  
  # Format individual labels: combine ID with formatted label text
  # Replace underscores with spaces and hyphens with newlines for readability
  ids <- paste(data_df$ID, gsub("_", " ",gsub("-", "\n", data_df$Label)), sep="\n")
  
  # Assign colors based on individual status:
  # Green (3) = ID 7 (respondent)
  # Red (2) = Has cancer diagnosis (any affected quadrant > 0)
  # Black (1) = Unaffected
  cols <- c(ifelse(data_df$ID == 7, 3,ifelse(data_df$ul + data_df$ur + data_df$ll + data_df$lr > 0  ,2 ,1)))
  
  # Create the pedigree object with all family relationship and status data
  myped <- pedigree(id=data_df$ID, dadid=data_df$Dadid, momid=data_df$Momid, sex=data_df$Sex, status=data_df$Status, affected=as.matrix(aff), famid=data_df$Ped)

  # Configure plot margins to accommodate legend text at bottom
  # Format: c(bottom, left, top, right) - extra space at bottom for 3-4 legend lines
  par(mar = c(6, 2, 1, 2))

  # Generate the pedigree plot for family '1'
  # symbolsize: controls the size of pedigree symbols
  # col: vector of colors (green for respondent, red for affected, black for unaffected)
  # cex: character expansion factor for text size
  plot(myped['1'], ids, symbolsize = 1.2, col=cols, cex=.7)

  # Add legend lines at the bottom of the plot
  # side 1 = bottom, line = distance from plot area, cex = text size
  mtext("Green = Respondent", side = 1, line = 2, cex = 0.8, col = "green")
  mtext("Red = Family member with cancer", side = 1, line = 3, cex = 0.8, col = "red")

  # Conditionally add asterisk explanation if data contains multiple diagnoses
  # The '*' character in labels indicates multiple occurrences of the same cancer type
  if (grepl("*", file_content, fixed = TRUE)) {
    mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 4, cex = 0.8, col = "black")
  }
}

#* Health check endpoint
#* 
#* Returns a simple status object to verify the API is running and responsive.
#* Used by container orchestration systems (Docker, Kubernetes) to monitor
#* service health.
#*
#* @get /healthz
function() {
  list(status = "ok")
}