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
  plot(myped['1'], ids, mar=c(2, 2, 2, 2), symbolsize = 1.2, col=cols, cex=.7)

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
    par(mar = c(4, 4, 4, 4))  # Adjust the margin size

    # Plot the pedigree with the updated color scheme
    plot(myped['1'], ids, symbolsize = 1.2, col = cols, cex = .7)

    # Add the legend
    legend(x = 0.8, y = 0.2, legend = c("green = Respondent", "red = Family member with cancer"),
        text.col = c("darkgreen", "red"), bty = "n", cex = 1.0, inset = c(-0.1, -0.1))

    # Close the PDF device
    dev.off()
    readBin(tmp, "raw", n=file.info(tmp)$size)
}