#!/usr/bin/env bash
set -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE=ghcr.io/puppeteer/puppeteer:23.10.4
readonly HOME_DIR=/home/pptruser

show_help()
{
  cat <<EOF
Usage: bin/capture_readme_images.sh [OPTIONS]

Rebuilds the demo report with bin/build_demo.sh, then opens
site/files/source/fee.rb.html in headless Chrome, in the Puppeteer
Docker image, and saves the README's two screenshots to docs/:
decision.png (the first if's grid) and method.png (fee's grid).
Run it again whenever the HTML report's look changes.

Options:
  -h    Show this help

Example:
  bin/capture_readme_images.sh
EOF
}

if [ "${1:-}" = '-h' ]; then
  show_help
  exit 0
fi

"${ROOT_DIR}/bin/build_demo.sh" > /dev/null
mkdir -p "${ROOT_DIR}/docs"

# Run as root so the bind-mounted docs/ is writable; the module
# and browser paths then name pptruser's, as root's home differs.
docker run --rm \
  --user root \
  --env "NODE_PATH=${HOME_DIR}/node_modules" \
  --env "PUPPETEER_CACHE_DIR=${HOME_DIR}/.cache/puppeteer" \
  --volume "${ROOT_DIR}/site:/site:ro" \
  --volume "${ROOT_DIR}/docs:/out" \
  --volume "${ROOT_DIR}/bin:/capture:ro" \
  "${IMAGE}" \
  node /capture/capture_readme_images.js

echo "${ROOT_DIR}/docs/decision.png"
echo "${ROOT_DIR}/docs/method.png"
