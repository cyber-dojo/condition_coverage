#!/usr/bin/env bash
set -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RUBY_IMAGE=path_coverage-test
readonly CHROME_IMAGE=ghcr.io/puppeteer/puppeteer:23.10.4
readonly HOME_DIR=/home/pptruser
readonly REPORT_DIR="${ROOT_DIR}/reports/popouts"

show_help()
{
  cat <<EOF
Usage: bin/capture_popout_images.sh [OPTIONS]

Runs demo/popouts/run.rb, one method per kind of popout cell,
under path coverage, writing its HTML report to reports/popouts/.
Then opens files/cells.rb.html in headless Chrome, in the
Puppeteer Docker image, and saves each method's popout to docs/,
eg docs/cell-blank.png, for the README's Reading the HTML report.
Run it again whenever the popout's look changes.

Options:
  -h    Show this help

Example:
  bin/capture_popout_images.sh
EOF
}

if [ "${1:-}" = '-h' ]; then
  show_help
  exit 0
fi

docker build --quiet --tag "${RUBY_IMAGE}" "${ROOT_DIR}" > /dev/null
mkdir -p "${REPORT_DIR}" "${ROOT_DIR}/docs"

# The report dir is emptied from inside the container, the side
# that writes it.
docker run --rm \
  --volume "${ROOT_DIR}:/gem:ro" \
  --volume "${REPORT_DIR}:/report" \
  --env COVERAGE_DIR=/report \
  "${RUBY_IMAGE}" \
  sh -c 'rm -rf /report/* && ruby -Ilib demo/popouts/run.rb'

# Run as root so the bind-mounted docs/ is writable; the module
# and browser paths then name pptruser's, as root's home differs.
docker run --rm \
  --user root \
  --env "NODE_PATH=${HOME_DIR}/node_modules" \
  --env "PUPPETEER_CACHE_DIR=${HOME_DIR}/.cache/puppeteer" \
  --volume "${REPORT_DIR}:/report:ro" \
  --volume "${ROOT_DIR}/docs:/out" \
  --volume "${ROOT_DIR}/bin:/capture:ro" \
  "${CHROME_IMAGE}" \
  node /capture/capture_popout_images.js

ls "${ROOT_DIR}"/docs/cell-*.png
