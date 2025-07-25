# Build the multi-arch image
docker buildx build --no-cache -t elicitsoftware/pedigree:latest --load .
