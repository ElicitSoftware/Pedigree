# Build the multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 --no-cache -t elicitsoftware/pedigree:Beta-1 --load .
