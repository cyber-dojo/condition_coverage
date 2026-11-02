require_relative 'test_helper'
require 'path_coverage/result'
require 'path_coverage/summary'

class SummaryTest < Id58TestBase
  test 'SEye10', %w(
  | each covered file gets one summary row for the index page:
  | its sites, the outcomes seen out of all possible,
  | as a percent too, and the outcomes missing
  ) do
    sites = {
      'source/kata.rb:3:23' => condition('&&', 72...79, 83...102),
      'source/kata.rb:4:24' => condition('&&', 127...134, 138...150),
      'source/team.rb:2:20' => condition('&&', 30...37, 41...52)
    }
    counts = {
      ['source/kata.rb:3:23', 0] => { truthy: 1, falsy: 1 },
      ['source/kata.rb:3:23', 1] => { truthy: 1, falsy: 0 },
      ['source/team.rb:2:20', 0] => { truthy: 2, falsy: 1 },
      ['source/team.rb:2:20', 1] => { truthy: 1, falsy: 1 }
    }
    operands = PathCoverage::Result.new(sites, counts).operands
    expected = [
      { path: 'source/kata.rb', sites: 2, seen: 3, outcomes: 8,
        percent: 38, missing: 5 },
      { path: 'source/team.rb', sites: 1, seen: 4, outcomes: 4,
        percent: 100, missing: 0 }
    ]
    actual = PathCoverage::Summary.files(operands)
    assert_equal expected, actual
  end

  test 'SEye20', %w(
  | a leaf that can have one outcome only adds one possible
  | outcome, not two, so a site seen every way it can be
  | is at 100 percent
  ) do
    fixed = { 54...72 => :truthy }
    sites = {
      'source/clock.rb:2:11' =>
        condition('||', 35...50, 54...72, fixed:)
    }
    counts = {
      ['source/clock.rb:2:11', 0] => { truthy: 1, falsy: 1 },
      ['source/clock.rb:2:11', 1] => { truthy: 1, falsy: 0 }
    }
    operands = PathCoverage::Result.new(sites, counts).operands
    expected = [
      { path: 'source/clock.rb', sites: 1, seen: 3, outcomes: 3,
        percent: 100, missing: 0 }
    ]
    actual = PathCoverage::Summary.files(operands)
    assert_equal expected, actual
  end
end
