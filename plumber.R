# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

library(plumber)
library(Matrix)
library(quadprog)
library(kinship2)
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

  # Increase margins if necessary - make bottom margin larger for text
  par(mar = c(6, 4, 4, 4))  # Increased bottom margin from 4 to 6

  plot(myped['1'], ids, symbolsize = 1.2, col=cols, cex=.7)

  # Add text at bottom of plot - two lines with different colors
  mtext("Green = Respondent", side = 1, line = 3, cex = 0.8, col = "green")
  mtext("Red = Family member with cancer", side = 1, line = 4, cex = 0.8, col = "red")

  # Check if '*' exists in the file content and add line if found
  if (grepl("\\*", file_content)) {
    mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 5, cex = 0.8, col = "black")
  }
}

#* Generates a pedigree svg image from a pedigree data frame
#* @post /pdf
#* @param ped:file A file
#* @serializer contentType list(type="application/pdf")
function(ped) {

    # Load necessary libraries
    require(plumber)
    require(Matrix)
    require(quadprog)
    require(kinship2)

    tmp <- tempfile()
    pdf(tmp, width = 11, height = 8.5)
    # Access the file content from the list ped[[1]]
    file_content <- ped[[1]]

    data_df <- read.table(text = file_content, header = TRUE,  sep = "\t", na.strings = "NA")
    print(data_df)
    aff <- data.frame(UL=data_df$ul, UR=data_df$ur, LL=data_df$ll, lr=data_df$lr)
    ids <- paste(data_df$ID, gsub("_", " ",gsub("-", "\n", data_df$Label)), sep="\n")
    cols <- c(ifelse(data_df$ID == 7, 3,ifelse(data_df$ul + data_df$ur + data_df$ll + data_df$lr > 0  ,2 ,1)))
    myped <- pedigree(id=data_df$ID, dadid=data_df$Dadid, momid=data_df$Momid, sex=data_df$Sex, status=data_df$Status, affected=as.matrix(aff), famid=data_df$Ped)

    # Increase margins if necessary
    par(mar = c(6, 4, 4, 4))  # Increased bottom margin to match SVG

    # Plot the pedigree with the updated color scheme
    plot(myped['1'], ids, symbolsize = 1.2, col = cols, cex = .7)

    # Add text at bottom of plot - two lines with different colors
    mtext("Green = Respondent", side = 1, line = 3, cex = 0.8, col = "green")
    mtext("Red = Family member with cancer", side = 1, line = 4, cex = 0.8, col = "red")

    # Check if '*' exists in the file content and add line if found
    if (grepl("\\*", file_content)) {
      mtext("* Indicates multiple diagnoses of the same cancer type.", side = 1, line = 5, cex = 0.8, col = "black")
    }

    # Close the PDF device
    dev.off()
    readBin(tmp, "raw", n=file.info(tmp)$size)
}