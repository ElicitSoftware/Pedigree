#!/bin/bash

# Elicit FHHS Pedigree API - Smoke Test
#
# Pedigree has no test suite of its own; this script is what proves an image still serves
# a pedigree. It starts a container from the image with a service token, waits for /healthz,
# checks that /svg refuses a request without the token or with a wrong one (401), posts the
# sample pedigree (ped1.txt, the one the README posts) to /svg with the token and checks
# that the answer is an SVG document and that the drawing left no temporary file behind.
# It checks that the service runs as the unprivileged user (uid 10001) and cannot write to
# /app, and that a request body over the 1 MB limit is refused (413) and the service still
# draws afterwards, and that a pedigree of more than 500 people is refused the same way. /healthz
# must report the image's version.
# Given an image, it then starts it twice more: without a token (/healthz 200, /svg 503)
# and with a token that is too short (the container must exit). No service log may contain
# a token. Both workflows run it: ci.yml on every pull request, and the release workflow
# before it pushes anything.
#
# Usage: ci/smoke.sh <image>               start a container from the image and test it
#        ci/smoke.sh --url <base address>  test a service that is already running,
#                                          e.g. ci/smoke.sh --url http://127.0.0.1:18083
#
# Environment:
#   SMOKE_PORT       host port the container is published on (default 8083)
#   SMOKE_CONTAINER  name of the container (default pedigree-smoke); with --url, name the
#                    running container here to include the temporary-file check
#   SMOKE_TOKEN      the service token: given to the container as ELICIT_SERVICE_TOKEN, or,
#                    with --url, the token the running service was started with. The default
#                    is a literal for this test only, never the token of a real site.
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
  sed -n '19,21p' "$0" | sed 's/^# //' >&2
  exit 2
fi

token="${SMOKE_TOKEN:-pedigree-ci-smoke-token-not-for-a-real-site}"
# The same length as the token, so only the value differs.
wrong_token="${token%?}"
if [[ "$token" == *x ]]; then wrong_token+="y"; else wrong_token+="x"; fi
short_token="too-short-for-a-token"
no_token_container="${container}-no-token"
short_token_container="${container}-short-token"

svg_out="$(mktemp)"
headers_out="$(mktemp)"
oversized="$(mktemp)"

# Runs on every exit: show the service log when a check failed, then remove what was started.
finish() {
  status=$?
  rm -f "$svg_out" "$headers_out" "$oversized"
  if [[ -n "$image" ]]; then
    if [[ $status -ne 0 ]]; then
      echo "--- service log ---" >&2
      docker logs "$container" >&2 2>&1 || true
    fi
    docker rm -f "$container" "$no_token_container" "$short_token_container" >/dev/null 2>&1 || true
  fi
  exit $status
}
trap finish EXIT

if [[ -n "$image" ]]; then
  docker run -d --name "$container" -p "${port}:8080" -e ELICIT_SERVICE_TOKEN="$token" "$image" >/dev/null
  echo "started $container from $image on port $port"
fi

# R loads Pedixplorer before plumber listens, so the first answers can take a while.
# /healthz is asked without a credential: it has to stay open to probes.
wait_healthy() {
  for _ in $(seq 1 60); do
    if curl -fsS "$base_url/healthz" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "pedigree did not become healthy within two minutes" >&2
  return 1
}

# Posts the sample pedigree to /svg with the given curl options, keeps the body in $svg_out
# and the response headers in $headers_out, and prints the status code.
post_svg() {
  curl -sS -o "$svg_out" -D "$headers_out" -w '%{http_code}' "$@" -F "ped=@ped1.txt" "$base_url/svg"
}

# A request that is refused: the expected status, and nothing of a drawing in the body.
expect_refused() {
  local what="$1" expected="$2" status
  shift 2
  status="$(post_svg "$@")"
  if [[ "$status" != "$expected" ]]; then
    echo "/svg $what: expected $expected, got $status" >&2
    exit 1
  fi
  if grep -q "<svg" "$svg_out"; then
    echo "/svg $what: answered $status but sent a drawing" >&2
    exit 1
  fi
  echo "/svg $what: $status"
}

# A 401 names the scheme and says nothing else.
expect_unauthorized() {
  expect_refused "$@"
  if ! grep -qi '^WWW-Authenticate: Bearer' "$headers_out"; then
    echo "/svg $1: the 401 has no WWW-Authenticate: Bearer header" >&2
    exit 1
  fi
  if [[ -s "$svg_out" ]]; then
    echo "/svg $1: the 401 has a body" >&2
    exit 1
  fi
}

# The container's whole log, read before it is searched. `docker logs | grep -q` would race
# under pipefail: grep -q stops at its first match, docker logs can then die of SIGPIPE, and the
# pipeline fails although grep matched (#28).
container_log() {
  docker logs "$1" 2>&1
}

# No log line may carry a token, whether it was accepted or refused.
expect_no_token_in_log() {
  local log
  log="$(container_log "$1")"
  if grep -q -F -e "$token" -e "$wrong_token" -e "$short_token" <<<"$log"; then
    echo "the log of $1 contains a service token" >&2
    exit 1
  fi
}

wait_healthy
health="$(curl -fsS "$base_url/healthz")"
echo "/healthz: $health"
# The image reports its version (the release tag, or "dev" for a local build).
if ! grep -q '"version"' <<<"$health"; then
  echo "/healthz names no version" >&2
  exit 1
fi

expect_unauthorized "without a credential" 401
expect_unauthorized "with a wrong token" 401 -H "Authorization: Bearer $wrong_token"
expect_unauthorized "with the token under another scheme" 401 -H "Authorization: Basic $token"

# The image serves no Swagger/OpenAPI pages (Pedigree#21), not even to a caller with the token.
for path in /__docs__/ /openapi.json; do
  status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" "$base_url$path")"
  if [[ "$status" != "404" ]]; then
    echo "$path with the token: expected 404, got $status" >&2
    exit 1
  fi
  echo "$path with the token: $status"
done

# The base image has SVG files of its own under /tmp, so the drawing is checked against a
# count taken before it. Counted as root: the image's own directories under /tmp are not
# readable by the service's user.
svg_files() {
  docker exec -u 0 "$container" sh -c 'find /tmp -name "*.svg" | wc -l' | tr -d ' '
}
if [[ -n "$container" ]]; then
  before="$(svg_files)"
fi

# The response has to be an SVG document.
status="$(post_svg -H "Authorization: Bearer $token")"
if [[ "$status" != "200" ]]; then
  echo "/svg with the token: expected 200, got $status" >&2
  exit 1
fi
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

# The service runs as the image's unprivileged user and cannot change its own code.
if [[ -n "$container" ]]; then
  uid="$(docker exec "$container" id -u)"
  if [[ "$uid" != "10001" ]]; then
    echo "the service runs as uid $uid, not 10001" >&2
    exit 1
  fi
  if docker exec "$container" sh -c 'touch /app/probe' >/dev/null 2>&1; then
    echo "/app is writable by the service" >&2
    exit 1
  fi
  echo "running as uid $uid; /app is not writable"
fi

# A body over the limit (1 MB) is refused, and the service draws the sample again afterwards.
head -c 2000000 /dev/zero | tr '\0' 'a' > "$oversized"
status="$(curl -sS -o "$svg_out" -w '%{http_code}' -H "Authorization: Bearer $token" -F "ped=@$oversized" "$base_url/svg")"
if [[ "$status" != "413" ]]; then
  echo "/svg with a 2 MB body: expected 413, got $status" >&2
  exit 1
fi
echo "/svg with a 2 MB body: $status"
status="$(post_svg -H "Authorization: Bearer $token")"
if [[ "$status" != "200" ]] || ! grep -q "<svg" "$svg_out"; then
  echo "/svg after a refused body: expected a drawing, got $status" >&2
  exit 1
fi
echo "/svg after a refused body: $status"

# A pedigree of more than 500 people is refused before it is laid out, and the service draws the
# sample again afterwards.
{
  printf 'famid\tid\tsex\tdadid\tmomid\tdeceased\tproband\taffection\tavail\tdisplay_id\tcancer_label\n'
  for i in $(seq 1 501); do printf '1\t%d\t1\tNA\tNA\t0\t0\t0\t1\tP%d\t\n' "$i" "$i"; done
} > "$oversized"
status="$(curl -sS -o "$svg_out" -w '%{http_code}' -H "Authorization: Bearer $token" -F "ped=@$oversized;type=text/plain" "$base_url/svg")"
if [[ "$status" != "413" ]]; then
  echo "/svg with 501 people: expected 413, got $status" >&2
  exit 1
fi
echo "/svg with 501 people: $status"
status="$(post_svg -H "Authorization: Bearer $token")"
if [[ "$status" != "200" ]] || ! grep -q "<svg" "$svg_out"; then
  echo "/svg after a refused pedigree: expected a drawing, got $status" >&2
  exit 1
fi

if [[ -n "$container" ]]; then
  expect_no_token_in_log "$container"
  echo "no token in the service log"
fi

# The two starts that are not a working service need containers of their own.
if [[ -n "$image" ]]; then
  docker rm -f "$container" >/dev/null

  # Without a token the service starts and stays alive, and refuses every drawing.
  container="$no_token_container"
  docker run -d --name "$container" -p "${port}:8080" "$image" >/dev/null
  wait_healthy
  echo "no token, /healthz: $(curl -fsS "$base_url/healthz")"
  expect_refused "on a service with no token" 503 -H "Authorization: Bearer $token"
  if [[ "$(cat "$svg_out")" != '{"error":"service token not configured"}' ]]; then
    echo "the 503 body is not the expected one:" >&2
    head -c 500 "$svg_out" >&2
    exit 1
  fi
  if ! grep -q "ELICIT_SERVICE_TOKEN is not set" <<<"$(container_log "$container")"; then
    echo "a service started without a token did not say so in its log" >&2
    exit 1
  fi
  expect_no_token_in_log "$container"
  docker rm -f "$container" >/dev/null

  # A token that is too short stops the start; the log names the variable, not the value.
  container="$short_token_container"
  docker run -d --name "$container" -e ELICIT_SERVICE_TOKEN="$short_token" "$image" >/dev/null
  running=true
  for _ in $(seq 1 60); do
    running="$(docker inspect -f '{{.State.Running}}' "$container")"
    if [[ "$running" != "true" ]]; then
      break
    fi
    sleep 2
  done
  exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$container")"
  if [[ "$running" == "true" || "$exit_code" == "0" ]]; then
    echo "a token that is too short did not stop the start" >&2
    exit 1
  fi
  if ! grep -q "ELICIT_SERVICE_TOKEN must be at least 32 characters" <<<"$(container_log "$container")"; then
    echo "the refused start does not name the variable and the length required" >&2
    exit 1
  fi
  expect_no_token_in_log "$container"
  echo "a token that is too short: the container exited with $exit_code"
fi

echo "smoke test passed"
