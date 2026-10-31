require_relative 'test_helper'
require_relative 'coverage_metrics_check'

class CoverageMetricsCheckTest < Id58TestBase
  test 'p0Kj10', %w(
    a missed count above its max is a breach
    naming the metric, its value and its range
  ) do
    report = {
      'code' => {
        'lines' => { 'total' => 22, 'missed' => 2 },
        'branches' => { 'total' => 0, 'missed' => 0 }
      }
    }
    bounds = {
      'code' => {
        'lines' => {
          'total' => { 'min' => 1, 'max' => 22 },
          'missed' => { 'min' => 0, 'max' => 0 }
        },
        'branches' => {
          'total' => { 'min' => 0, 'max' => 0 },
          'missed' => { 'min' => 0, 'max' => 0 }
        }
      }
    }
    expected = ['code.lines.missed: 2 is outside 0..0']
    actual = CoverageMetricsCheck.breaches(report, bounds)
    assert_equal expected, actual
  end

  test 'p0Kj20', %w(
    a total below its min is a breach, so an all-zeros report
    from a run that loaded no code cannot pass
  ) do
    report = {
      'test' => {
        'lines' => { 'total' => 0, 'missed' => 0 },
        'branches' => { 'total' => 0, 'missed' => 0 }
      }
    }
    bounds = {
      'test' => {
        'lines' => {
          'total' => { 'min' => 1, 'max' => 111 },
          'missed' => { 'min' => 0, 'max' => 0 }
        },
        'branches' => {
          'total' => { 'min' => 1, 'max' => 16 },
          'missed' => { 'min' => 0, 'max' => 0 }
        }
      }
    }
    expected = [
      'test.lines.total: 0 is outside 1..111',
      'test.branches.total: 0 is outside 1..16'
    ]
    actual = CoverageMetricsCheck.breaches(report, bounds)
    assert_equal expected, actual
  end

  test 'p0Kj30', %w(
    a bounded metric absent from the report is a breach
    saying so, rather than passing unchecked
  ) do
    report = {
      'code' => {
        'lines' => { 'total' => 22, 'missed' => 0 }
      }
    }
    bounds = {
      'code' => {
        'lines' => {
          'total' => { 'min' => 1, 'max' => 22 },
          'missed' => { 'min' => 0, 'max' => 0 }
        },
        'branches' => {
          'total' => { 'min' => 0, 'max' => 0 }
        }
      }
    }
    expected = ['code.branches.total: missing from the report']
    actual = CoverageMetricsCheck.breaches(report, bounds)
    assert_equal expected, actual
  end

  test 'p0Kj40', %w(
    a bound naming only its min is a breach saying so,
    since applying the one side it has would half check it
  ) do
    report = {
      'code' => {
        'lines' => { 'total' => 22, 'missed' => 0 }
      }
    }
    bounds = {
      'code' => {
        'lines' => {
          'total' => { 'min' => 1, 'max' => 22 },
          'missed' => { 'min' => 0 }
        }
      }
    }
    expected = ['code.lines.missed: bound names min but no max']
    actual = CoverageMetricsCheck.breaches(report, bounds)
    assert_equal expected, actual
  end

  test 'p0Kj50', %w(
    a bound naming only its max is a breach saying so,
    since an all-zeros report would satisfy it
  ) do
    report = {
      'code' => {
        'lines' => { 'total' => 22, 'missed' => 0 }
      }
    }
    bounds = {
      'code' => {
        'lines' => {
          'total' => { 'max' => 22 },
          'missed' => { 'min' => 0, 'max' => 0 }
        }
      }
    }
    expected = ['code.lines.total: bound names max but no min']
    actual = CoverageMetricsCheck.breaches(report, bounds)
    assert_equal expected, actual
  end
end
