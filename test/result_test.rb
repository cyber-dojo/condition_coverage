require_relative 'test_helper'
require 'condition_coverage/result'

class ResultTest < Id58TestBase
  test 'DYTY10', %w(
  | the result lists every site in the manifest
  | with the counts of each of its operands,
  | zero for an operand or a whole site that never ran
  ) do
    sites = { 'k.rb:2:2' => 2, 'k.rb:6:4' => 2 }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 2, falsy: 1 },
      ['k.rb:2:2', 1] => { truthy: 1, falsy: 1 }
    }
    expected = {
      'k.rb:2:2' => [
        { truthy: 2, falsy: 1 },
        { truthy: 1, falsy: 1 }
      ],
      'k.rb:6:4' => [
        { truthy: 0, falsy: 0 },
        { truthy: 0, falsy: 0 }
      ]
    }
    actual = ConditionCoverage::Result.new(sites, counts).operands
    assert_equal expected, actual
  end
end
