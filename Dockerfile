FROM rstudio/plumber:latest

    RUN apt update && apt-get full-upgrade -y

    RUN R -e "install.packages('kinship2', dependencies=TRUE, repos='http://cran.us.r-project.org')"

    # Create app directory
    RUN mkdir -p /app

    # Copy plumber API file to container
    COPY plumber.R /app/plumber.R
    COPY Notice.txt /app/

    # Set working directory
    WORKDIR /app

    # Expose port 8080
    EXPOSE 8080

    # Run plumber API
    CMD ["/app/plumber.R"]