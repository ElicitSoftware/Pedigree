# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

library(plumber)
library(Matrix)
library(quadprog)
library(kinship2)
options("plumber.port" = 8080)
#* @apiTitle Elicit FHHS Kinship API
#* @apiDescription Elicit FHHS Kinship Example

#* Generates a pedigree svg image from a pedigree data frame
#* @post /svg
#* @param ped:file A file
#* @serializer svg
function(ped) {

  require(plumber)
  require(Matrix)
  require(quadprog)
  require(kinship2)

  # Access the file content from the list ped[[1]]
  file_content <- ped[[1]]

  data_df <- read.table(text = file_content, header = TRUE,  sep = "\t", na.strings = "NA")
  print(data_df)
  aff <- data.frame(UL=data_df$ul, UR=data_df$ur, LL=data_df$ll, lr=data_df$lr)
  ids <- paste(data_df$ID, gsub("_", " ",gsub("-", "\n", data_df$Label)), sep="\n")
  cols <- c(ifelse(data_df$ID == 7, 3,ifelse(data_df$ul + data_df$ur + data_df$ll + data_df$lr > 0  ,2 ,1)))
  myped <- pedigree(id=data_df$ID, dadid=data_df$Dadid, momid=data_df$Momid, sex=data_df$Sex, status=data_df$Status, affected=as.matrix(aff), famid=data_df$Ped)

  # Increase bottom margin to accommodate all text lines
  par(mar = c(6, 2, 1, 2))

  plot(myped['1'], ids, symbolsize = 1.2, col=cols, cex=.7)

  # Add text at bottom of plot using mtext() with proper spacing
  mtext("Green = Respondent", side = 1, line = 2, cex = 0.8, col = "green")
  mtext("Red = Family member with cancer", side = 1, line = 3, cex = 0.8, col = "red")

  # Check if '*' exists in the file content and add line if found
  if (grepl("\\*", file_content)) {
    mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 4, cex = 0.8, col = "black")
  }
}

#* Health check endpoint
#* @get /healthz
function() {
  list(status = "ok")
}