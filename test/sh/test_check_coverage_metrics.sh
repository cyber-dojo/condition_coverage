#!/usr/bin/env bash

# Tests for bin/check_coverage_metrics.rb, asserting on its exit
# status as well as its output: make reads the status, so a check
# that printed DENIED but exited 0 would leave a breach green.

readonly my_dir="$(cd "$(dirname "${0}")" && pwd)"
readonly repo_dir="$(cd "${my_dir}/../.." && pwd)"

readonly REPORT='{
  "code": { "lines": { "total": 33, "missed": 0 } }
}'

readonly MET_PARAMS='{
  "bounds": {
    "code": {
      "lines": {
        "total":  {"min": 1, "max": 33},
        "missed": {"min": 0, "max": 0}
      }
    }
  }
}'

# Gives each test a directory no container has mounted before:
# a bind-mounted file rewritten on the host can read back empty
# in the next container (Docker Desktop file sharing).
setUp()
{
  fixtures_dir="$(mktemp -d "${SHUNIT_TMPDIR}/fixtures.XXXXXX")"
}

# Writes the report and params JSON to files, then checks them.
check()
{
  printf '%s' "${1}" > "${fixtures_dir}/report.json"
  printf '%s' "${2}" > "${fixtures_dir}/params.json"
  run_check /fixtures/report.json /fixtures/params.json
}

# Runs the check in the test image, as bin/run_tests.sh does, on
# files named by their path in /fixtures (fixtures_dir mounted),
# capturing stdout, stderr and status.
run_check()
{
  docker run --rm \
    --volume "${repo_dir}:/gem:ro" \
    --volume "${fixtures_dir}:/fixtures:ro" \
    path_coverage-test \
    ruby bin/check_coverage_metrics.rb "$@" \
    > "${stdoutF}" 2> "${stderrF}"
  echo $? > "${statusF}"
}

test_met_bounds_exit_0_saying_allowed()
{
  check "${REPORT}" "${MET_PARAMS}"
  assert_status_0
  assert_stdout_equals 'coverage: ALLOWED'
  assert_stderr_empty
}

test_a_breached_bound_exits_1_naming_the_breach()
{
  local -r params="${MET_PARAMS/\"max\": 33/\"max\": 32}"
  check "${REPORT}" "${params}"
  assert_status_equals 1
  assert_stdout_equals "$(printf '%s\n%s' \
    'code.lines.total: 33 is outside 1..32' 'coverage: DENIED')"
  assert_stderr_empty
}

test_a_missing_report_exits_1_naming_the_file()
{
  printf '%s' "${MET_PARAMS}" > "${fixtures_dir}/params.json"
  run_check /fixtures/absent.json /fixtures/params.json
  assert_status_equals 1
  assert_stdout_empty
  assert_stderr_equals '/fixtures/absent.json: no such file'
}

test_params_without_bounds_exit_1_rather_than_check_nothing()
{
  check "${REPORT}" '{}'
  assert_status_equals 1
  assert_stdout_empty
  assert_stderr_equals \
    '/fixtures/params.json: no "bounds" key, so nothing would be checked'
}

test_a_report_that_is_not_json_exits_1_naming_the_file()
{
  check 'coverage report' "${MET_PARAMS}"
  assert_status_equals 1
  assert_stdout_empty
  assert_stderr_includes '/fixtures/report.json: not valid JSON: '
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "::${0##*/}"
. "${my_dir}/shunit2_helpers.sh"
. "${my_dir}/shunit2"
