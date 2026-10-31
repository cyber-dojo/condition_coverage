#!/usr/bin/env bash
set -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE=condition_coverage-test

show_help()
{
  cat <<EOF
Usage: bin/lint.sh [OPTIONS]

Runs rubocop over the whole repo (lib/, test/ and bin/ alike) in
the Docker image built from the repo's Dockerfile, exiting
non-zero if it finds any offense.

Options:
  -h    Show this help

Example:
  bin/lint.sh
EOF
}

if [ "${1:-}" = '-h' ]; then
  show_help
  exit 0
fi

docker build --quiet --tag "${IMAGE}" "${ROOT_DIR}" > /dev/null

docker run --rm \
  --volume "${ROOT_DIR}:/gem:ro" \
  "${IMAGE}" \
  rubocop --cache false
