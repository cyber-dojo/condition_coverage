.PHONY: all image test test_check lint

# Everything a change must pass before it is committed.
all: lint test test_check

image:
	docker build --tag condition_coverage-test ${PWD}

# A full run also gates the coverage report against
# test/coverage_metrics_params.json. tids runs only the tests
# whose id58 contains one of its values, and skips that gate.
#   eg make test tids='6D1K p0Kj'
test:
	${PWD}/bin/run_tests.sh ${tids}

# Check that the coverage gate can fail: that a breached bound
# reaches make as a non-zero exit, not merely a line of output.
test_check:
	bash ${PWD}/test/sh/test_check_coverage_metrics.sh

lint:
	${PWD}/bin/lint.sh
