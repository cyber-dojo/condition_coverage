#!/usr/bin/env bash
set -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE=condition_coverage-test

show_help()
{
  cat <<EOF
Usage: bin/build_demo.sh [OPTIONS]

Runs demo/run.rb, a mock source tree under condition coverage, in
the Docker image built from the repo's Dockerfile, writing its
HTML report to site/ (index.html first). The same site is what
the GitHub Pages workflow publishes.

Options:
  -h    Show this help

Example:
  bin/build_demo.sh
EOF
}

if [ "${1:-}" = '-h' ]; then
  show_help
  exit 0
fi

docker build --quiet --tag "${IMAGE}" "${ROOT_DIR}" > /dev/null
mkdir -p "${ROOT_DIR}/site"

# site/ is emptied from inside the container, the side that writes
# it: emptied on the host, the bind mount can then fail to write it.
docker run --rm \
  --volume "${ROOT_DIR}:/gem:ro" \
  --volume "${ROOT_DIR}/site:/site" \
  --env COVERAGE_DIR=/site \
  "${IMAGE}" \
  sh -c 'rm -rf /site/* && ruby -Ilib demo/run.rb'

echo "${ROOT_DIR}/site/index.html"
