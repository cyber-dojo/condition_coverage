require_relative 'test_helper'
require 'condition_coverage/gaps'
require 'condition_coverage/result'

class GapsTest < Id58TestBase
  test 'ngWa10', %w(
  | only the gaps are reported, one line each:
  | an operand never false, never true or never evaluated,
  | and a site never reached at all
  ) do
    sites = {
      'k.rb:2:2' => condition('&&', 16...23, 27...35),
      'k.rb:6:4' => condition('&&', 57...64, 68...77),
      'k.rb:9:4' => condition('&&', 95...102, 106...118),
      'k.rb:12:4' => condition('&&', 136...143, 147...156)
    }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 3, falsy: 0 },
      ['k.rb:9:4', 0] => { truthy: 2, falsy: 1 },
      ['k.rb:9:4', 1] => { truthy: 0, falsy: 2 },
      ['k.rb:12:4', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:12:4', 1] => { truthy: 1, falsy: 1 }
    }
    operands = ConditionCoverage::Result.new(sites, counts).operands
    expected = [
      'k.rb:2:2 operand 0 never false',
      'k.rb:2:2 operand 1 never evaluated',
      'k.rb:6:4 never reached',
      'k.rb:9:4 operand 1 never true'
    ]
    actual = ConditionCoverage::Gaps.lines(operands)
    assert_equal expected, actual
  end

  test 'ngWa20', %w(
  | a leaf that can have one outcome only has no gap once
  | it is evaluated, its other outcome being impossible
  ) do
    fixed = { 54...72 => :truthy }
    sites = {
      'k.rb:2:11' => condition('||', 35...50, 54...72, fixed:)
    }
    counts = {
      ['k.rb:2:11', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:2:11', 1] => { truthy: 1, falsy: 0 }
    }
    operands = ConditionCoverage::Result.new(sites, counts).operands
    assert_equal [], ConditionCoverage::Gaps.lines(operands)
  end

  test 'ngWa30', %w(
  | a ternary whose predicate has several leaves has a gap
  | of its own when its predicate was only ever one way, as
  | one of its arms never ran; a ternary of one leaf has
  | that leaf's gap only, and an && never has one of its own
  ) do
    either = condition('||', 16...23, 27...35)
    sites = {
      'k.rb:2:2' => condition('?:', either),
      'k.rb:5:2' => condition('?:', 60...67),
      'k.rb:8:2' => condition('&&', 90...97, 101...109)
    }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:2:2', 1] => { truthy: 1, falsy: 0 },
      ['k.rb:5:2', 0] => { truthy: 2, falsy: 0 },
      ['k.rb:8:2', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:8:2', 1] => { truthy: 1, falsy: 1 }
    }
    outcomes = {
      'k.rb:2:2' => { truthy: 2, falsy: 0 },
      'k.rb:5:2' => { truthy: 2, falsy: 0 },
      'k.rb:8:2' => { truthy: 1, falsy: 0 }
    }
    result = ConditionCoverage::Result.new(sites, counts, outcomes)
    expected = [
      'k.rb:2:2 outcome never false',
      'k.rb:2:2 operand 1 never false',
      'k.rb:5:2 operand 0 never false'
    ]
    actual = ConditionCoverage::Gaps.lines(
      result.operands, result.outcomes
    )
    assert_equal expected, actual
  end

  test 'ngWa31', %w(
  | a ternary of several leaves whose predicate was never
  | true has a never-true gap of its own, its then arm
  | never having run
  ) do
    both = condition('&&', 16...23, 27...35)
    sites = { 'k.rb:2:2' => condition('?:', both) }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:2:2', 1] => { truthy: 0, falsy: 1 }
    }
    outcomes = { 'k.rb:2:2' => { truthy: 0, falsy: 2 } }
    result = ConditionCoverage::Result.new(sites, counts, outcomes)
    expected = [
      'k.rb:2:2 outcome never true',
      'k.rb:2:2 operand 1 never true'
    ]
    actual = ConditionCoverage::Gaps.lines(
      result.operands, result.outcomes
    )
    assert_equal expected, actual
  end

  test 'ngWa32', %w(
  | a ternary of several leaves whose predicate was seen
  | both ways, both arms having run, has no gap of its own
  ) do
    both = condition('&&', 16...23, 27...35)
    sites = { 'k.rb:2:2' => condition('?:', both) }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 2, falsy: 1 },
      ['k.rb:2:2', 1] => { truthy: 1, falsy: 1 }
    }
    outcomes = { 'k.rb:2:2' => { truthy: 1, falsy: 2 } }
    result = ConditionCoverage::Result.new(sites, counts, outcomes)
    actual = ConditionCoverage::Gaps.lines(
      result.operands, result.outcomes
    )
    assert_equal [], actual
  end
end
