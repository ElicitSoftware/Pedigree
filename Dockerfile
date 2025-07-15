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
    ENTRYPOINT ["R", "-e", "pr <- plumber::plumb(rev(commandArgs())[1]); args <- list(host = '0.0.0.0', port = 8080); if (packageVersion('plumber') >= '1.0.0') { pr$setDocs(TRUE) } else { args$swagger <- TRUE }; do.call(pr$run, args)"]

    # Run plumber API
    CMD ["/app/plumber.R"]