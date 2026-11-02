#!/usr/bin/env bash
set -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE=path_coverage-test

show_help()
{
  cat <<EOF
Usage: bin/run_tests.sh [OPTIONS] [ID58...]

Runs the tests in a Docker image built from the repo's Dockerfile,
then checks the coverage report against the bounds in
test/coverage_metrics_params.json, exiting non-zero if a test
fails or a bound is breached.

With ID58 arguments, runs only the tests whose id contains one of
them, and skips the coverage check: a partial run covers only
part of the code, so its report cannot meet the bounds.

Options:
  -h    Show this help

Examples:
  bin/run_tests.sh
  bin/run_tests.sh 2m4 Kp9
EOF
}

if [ "${1:-}" = '-h' ]; then
  show_help
  exit 0
fi

docker build --quiet --tag "${IMAGE}" "${ROOT_DIR}" > /dev/null

# A run that dies before SimpleCov writes must not leave the
# previous run's report for the check to pass on. It is deleted
# from inside the container, the side that writes it: deleted on
# the host, the bind mount can then fail to recreate it (ENOENT).
readonly LOADER='
$stdout.sync = true
report = "/reports/coverage_metrics.json"
File.delete(report) if File.exist?(report)
require "/gem/test/simplecov_config"
Dir["test/**/*_test.rb"].shuffle.each { |file| require File.expand_path(file) }
'

mkdir -p "${ROOT_DIR}/reports"

run_in_image()
{
  docker run --rm \
    --volume "${ROOT_DIR}:/gem:ro" \
    --volume "${ROOT_DIR}/reports:/reports" \
    --env RUBYOPT='-W2 --enable-frozen-string-literal' \
    "${IMAGE}" \
    "$@"
}

run_in_image ruby -Ilib -Itest -e "${LOADER}" -- "$@"

if [ $# -eq 0 ]; then
  run_in_image ruby bin/check_coverage_metrics.rb
fi
