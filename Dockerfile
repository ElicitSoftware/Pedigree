# Elicit FHHS Pedigree API Docker Image
#
# This Dockerfile creates a containerized R Plumber API for generating family
# pedigree diagrams. It uses the official RStudio Plumber base image and adds
# the kinship2 package for pedigree visualization.

# Base image: RStudio's official Plumber image with R and dependencies pre-installed
FROM rstudio/plumber:latest

    # Update all system packages to latest versions for security and stability
    # Clean up apt cache to reduce image size
    RUN apt-get update && apt-get full-upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

    # Install the kinship2 package from CRAN
    # This package provides pedigree plotting and kinship calculation functions
    # dependencies=TRUE ensures all required dependencies are also installed
    RUN R -e "install.packages('kinship2', dependencies=TRUE, repos='http://cran.us.r-project.org')"

    # Create application directory inside the container
    RUN mkdir -p /app

    # Copy application files into the container
    # plumber.R: Main API definition with endpoint logic
    # Notice.txt: Legal notices and licensing information
    COPY plumber.R /app/plumber.R
    COPY Notice.txt /app/

    # Set the working directory for subsequent commands
    WORKDIR /app

    # Expose port 8080 to allow external access to the API
    EXPOSE 8080
    
    # Configure the container to run the Plumber API when started
    # This command:
    # - Uses plumber::plumb() to load the API definition
    # - Binds to 0.0.0.0 to accept connections from any network interface
    # - Listens on port 8080
    # - Enables Swagger/OpenAPI documentation if supported by plumber version
    ENTRYPOINT ["R", "-e", "pr <- plumber::plumb(rev(commandArgs())[1]); args <- list(host = '0.0.0.0', port = 8080); if (packageVersion('plumber') >= '1.0.0') { pr$setDocs(TRUE) } else { args$swagger <- TRUE }; do.call(pr$run, args)"]

    # Specify the API file to be loaded by the ENTRYPOINT
    CMD ["/app/plumber.R"]