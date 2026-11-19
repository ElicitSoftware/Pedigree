#!/bin/bash

# Elicit FHHS Pedigree API - Docker Image Build Script
#
# This script builds the Docker image for the Pedigree API with Docker Buildx,
# for the platform of the machine it runs on, and loads it into the local
# Docker daemon. The multi-architecture release image (amd64, arm64) is built
# and pushed by the release workflow (.github/workflows/maven.yml), not here.
#
# Usage: ./buildDockerImage.sh
#
# Prerequisites:
# - Docker with Buildx support (Docker Desktop or Docker Engine 19.03+)

# Build the Docker image for the local platform
# --no-cache: Forces a fresh build without using cached layers. Every input is pinned in the
#   Dockerfile, so a fresh build installs the same versions; it proves they still resolve.
# -t elicitsoftware/pedigree:latest: Tags the image with repository name and version
# --load: Loads the built image into the local Docker daemon (a single-platform build)
# .: Build context is the current directory (where Dockerfile is located)
docker buildx build --no-cache -t elicitsoftware/pedigree:latest --load .
