#!/bin/bash

# Elicit FHHS Pedigree API - Docker Image Build Script
#
# This script builds a multi-architecture Docker image for the Pedigree API
# using Docker Buildx. The resulting image can run on multiple platforms
# (e.g., amd64, arm64) from a single build.
#
# Usage: ./buildDockerImage.sh
#
# Prerequisites:
# - Docker with Buildx support (Docker Desktop or Docker Engine 19.03+)
# - Buildx builder instance configured for multi-platform builds

# Build the multi-architecture Docker image
# --no-cache: Forces a fresh build without using cached layers (ensures latest dependencies)
# -t elicitsoftware/pedigree:latest: Tags the image with repository name and version
# --load: Loads the built image into the local Docker daemon (required for single-platform builds)
# .: Build context is the current directory (where Dockerfile is located)
docker buildx build --no-cache -t elicitsoftware/pedigree:latest --load .
