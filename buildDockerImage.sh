# Build the multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 --no-cache -t elicitsoftware/pedigree:1.0.0-alpha.1 --push .
