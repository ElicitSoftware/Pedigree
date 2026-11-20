# Elicit FHHS Pedigree API Docker Image
#
# This Dockerfile creates a containerized R Plumber API for generating family
# pedigree diagrams with the Pedixplorer package.
#
# Every input is pinned, so two builds of one commit install the same software (Pedigree#21):
# - the base image by R version and by the digest of its multi-architecture index, which holds
#   a real linux/amd64 and a real linux/arm64 image (rstudio/plumber, the former base, is
#   published for amd64 only, so the "arm64" image built from it held amd64 binaries);
# - CRAN by a dated Posit Package Manager snapshot, which serves Linux binaries for both
#   architectures;
# - Bioconductor by its release, which fixes the version of every package in it;
# - and the build fails unless plumber and Pedixplorer arrive at the versions named below.
# To update, move the digest, the snapshot date and the versions together, and let CI prove it.

# rocker/r-ver:4.6.2, multi-architecture index digest.
FROM rocker/r-ver:4.6.2@sha256:4383092318935c298533466f753354a7dfdc75a6e12edfb93a0f13c8a97135f9

ARG CRAN_SNAPSHOT=https://p3m.dev/cran/__linux__/resolute/2026-11-18
ARG BIOC_VERSION=3.23
ARG PLUMBER_VERSION=1.3.3
ARG PEDIXPLORER_VERSION=1.8.0

    # Runtime libraries the binary packages link against: libsodium (sodium, the service
    # token's HMAC), libglpk (igraph, a Pedixplorer dependency), libcurl/libssl/libxml2
    # (plumber and Bioconductor's installer) and cairo (the SVG device).
    RUN apt-get update \
        && apt-get install -y --no-install-recommends \
            libsodium23 libglpk40 libcurl4t64 libssl3t64 libxml2-16 libcairo2 libpng16-16t64 \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

    # CRAN from the dated snapshot for every later install, in place of rocker's "latest".
    RUN echo "options(repos = c(CRAN = '${CRAN_SNAPSHOT}'))" >> "$(R RHOME)/etc/Rprofile.site"

    RUN Rscript -e "install.packages(c('plumber', 'sodium', 'BiocManager'))" \
        && Rscript -e "BiocManager::install('Pedixplorer', version = '${BIOC_VERSION}', ask = FALSE, update = FALSE)" \
        && Rscript -e "for (p in c('plumber', 'sodium', 'Pedixplorer')) message(p, ' ', packageVersion(p))" \
        && Rscript -e "stopifnot(packageVersion('plumber') == '${PLUMBER_VERSION}', \
                                 packageVersion('Pedixplorer') == '${PEDIXPLORER_VERSION}', \
                                 capabilities('cairo')); \
                       library(sodium); library(Pedixplorer)"

    # Create application directory inside the container
    RUN mkdir -p /app

    # Copy application files into the container
    # plumber.R: Main API definition with endpoint logic
    # Notice.txt: Legal notices and licensing information
    COPY plumber.R /app/plumber.R
    COPY Notice.txt /app/

    # Set the working directory for subsequent commands
    WORKDIR /app

    # Run as an unprivileged user: the service needs no privilege, it listens on 8080 and
    # writes only to R's temporary directory under /tmp. /app stays owned by root, so the
    # service cannot rewrite its own handler. The user is numeric so that an orchestrator
    # can verify "not root" without reading /etc/passwd; HOME is /tmp because the user has
    # no home directory and the graphics libraries look for a cache under it.
    RUN useradd --system --no-create-home --uid 10001 --shell /usr/sbin/nologin pedigree
    ENV HOME=/tmp
    USER 10001

    # The version the image is released as, set by the release workflow from the git tag; a
    # local build is "dev". /healthz reports it, and it is the image's OCI version label.
    ARG VERSION=dev
    ENV PEDIGREE_VERSION=$VERSION
    LABEL org.opencontainers.image.version=$VERSION

    # Expose port 8080 to allow external access to the API
    EXPOSE 8080

    # Configure the container to run the Plumber API when started
    # This command:
    # - Uses plumber::plumb() to load the API definition
    # - Binds to 0.0.0.0 to accept connections from any network interface
    # - Listens on port 8080
    # - Serves no Swagger/OpenAPI pages: nothing in the platform reads them (Pedigree#21)
    ENTRYPOINT ["R", "-e", "pr <- plumber::plumb(rev(commandArgs())[1]); pr$setDocs(FALSE); pr$run(host = '0.0.0.0', port = 8080)"]

    # Specify the API file to be loaded by the ENTRYPOINT
    CMD ["/app/plumber.R"]
