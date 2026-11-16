#!/bin/bash

# Elicit FHHS Pedigree API - Smoke Test
#
# Pedigree has no test suite of its own; this script is what proves an image still serves
# a pedigree. It starts a container from the image, waits for /healthz, posts the sample
# pedigree (ped1.txt, the one the README posts) to /svg and checks that the answer is an
# SVG document and that the drawing left no temporary file behind. Both workflows run it:
# ci.yml on every pull request, and the release workflow before it pushes anything.
#
# Usage: ci/smoke.sh <image>               start a container from the image and test it
#        ci/smoke.sh --url <base address>  test a service that is already running,
#                                          e.g. ci/smoke.sh --url http://127.0.0.1:18083
#
# Environment:
#   SMOKE_PORT       host port the container is published on (default 8083)
#   SMOKE_CONTAINER  name of the container (default pedigree-smoke); with --url, name the
#                    running container here to include the temporary-file check
#
# Prerequisites: docker (not needed with --url) and curl.

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -eq 2 && "$1" == "--url" ]]; then
  image=""
  base_url="${2%/}"
  container="${SMOKE_CONTAINER:-}"
elif [[ $# -eq 1 && "$1" != -* ]]; then
  image="$1"
  port="${SMOKE_PORT:-8083}"
  base_url="http://localhost:${port}"
  container="${SMOKE_CONTAINER:-pedigree-smoke}"
else
  sed -n '11,13p' "$0" | sed 's/^# //' >&2
  exit 2
fi

svg_out="$(mktemp)"

# Runs on every exit: show the service log when a check failed, then remove what was started.
finish() {
  status=$?
  rm -f "$svg_out"
  if [[ -n "$image" ]]; then
    if [[ $status -ne 0 ]]; then
      echo "--- service log ---" >&2
      docker logs "$container" >&2 2>&1 || true
    fi
    docker rm -f "$container" >/dev/null 2>&1 || true
  fi
  exit $status
}
trap finish EXIT

if [[ -n "$image" ]]; then
  docker run -d --name "$container" -p "${port}:8080" "$image" >/dev/null
  echo "started $container from $image on port $port"
fi

# R loads Pedixplorer before plumber listens, so the first answers can take a while.
healthy=0
for _ in $(seq 1 60); do
  if curl -fsS "$base_url/healthz" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ $healthy -ne 1 ]]; then
  echo "pedigree did not become healthy within two minutes" >&2
  exit 1
fi
echo "/healthz: $(curl -fsS "$base_url/healthz")"

# The base image has SVG files of its own under /tmp, so the drawing is checked against a
# count taken before it.
svg_files() {
  docker exec "$container" sh -c 'find /tmp -name "*.svg" | wc -l' | tr -d ' '
}
if [[ -n "$container" ]]; then
  before="$(svg_files)"
fi

# The response has to be an SVG document.
curl -fsS -o "$svg_out" -F "ped=@ped1.txt" "$base_url/svg"
if ! grep -q "<svg" "$svg_out"; then
  echo "response is not SVG:" >&2
  head -c 500 "$svg_out" >&2
  exit 1
fi
echo "rendered $(wc -c < "$svg_out" | tr -d ' ') bytes of SVG"

# A drawing is written to a temporary file that is removed once it has been read.
if [[ -n "$container" ]]; then
  after="$(svg_files)"
  if [[ "$after" != "$before" ]]; then
    echo "temporary SVG files left in the container after the drawing: $before before, $after after" >&2
    exit 1
  fi
  echo "no temporary SVG file left behind"
fi

echo "smoke test passed"
