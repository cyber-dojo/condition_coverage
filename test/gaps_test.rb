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
    result = ConditionCoverage::Result.new(sites, counts)
    expected = [
      'k.rb:2:2 operand 0 never false',
      'k.rb:2:2 operand 1 never evaluated',
      'k.rb:6:4 never reached',
      'k.rb:9:4 operand 1 never true'
    ]
    actual = ConditionCoverage::Gaps.lines(result)
    assert_equal expected, actual
  end
end
