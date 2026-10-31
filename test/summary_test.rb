require_relative 'test_helper'
require 'condition_coverage/result'
require 'condition_coverage/summary'

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
    result = ConditionCoverage::Result.new(sites, counts)
    expected = [
      { path: 'source/kata.rb', sites: 2, seen: 3, outcomes: 8,
        percent: 38, missing: 5 },
      { path: 'source/team.rb', sites: 1, seen: 4, outcomes: 4,
        percent: 100, missing: 0 }
    ]
    actual = ConditionCoverage::Summary.files(result)
    assert_equal expected, actual
  end
end
