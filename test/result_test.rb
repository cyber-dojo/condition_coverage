require_relative 'test_helper'
require 'condition_coverage/result'

class ResultTest < Id58TestBase
  test 'DYTY10', %w(
  | the result lists every site in the manifest
  | with the counts of each of its operands,
  | zero for an operand or a whole site that never ran
  ) do
    sites = {
      'k.rb:2:2' => condition('&&', 16...23, 27...35),
      'k.rb:6:4' => condition('&&', 57...64, 68...77)
    }
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

  test 'DYTY20', %w(
  | the counts of a leaf that can have one outcome only
  | say which, so reporters demand that outcome alone
  ) do
    fixed = { 54...72 => :truthy }
    sites = {
      'k.rb:2:11' => condition('||', 35...50, 54...72, fixed:)
    }
    counts = {
      ['k.rb:2:11', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:2:11', 1] => { truthy: 1, falsy: 0 }
    }
    expected = {
      'k.rb:2:11' => [
        { truthy: 1, falsy: 1 },
        { truthy: 1, falsy: 0, only: :truthy }
      ]
    }
    actual = ConditionCoverage::Result.new(sites, counts).operands
    assert_equal expected, actual
  end

  test 'DYTY30', %w(
  | the result lists every site's own outcome counts, zero
  | for a site that never ran, a ternary's marked as such,
  | since its outcome picks an arm
  ) do
    sites = {
      'k.rb:2:2' => condition('&&', 16...23, 27...35),
      'k.rb:6:4' => condition('?:', 57...64)
    }
    outcomes = { 'k.rb:2:2' => { truthy: 2, falsy: 1 } }
    expected = {
      'k.rb:2:2' => { truthy: 2, falsy: 1 },
      'k.rb:6:4' => { truthy: 0, falsy: 0, ternary: true }
    }
    result = ConditionCoverage::Result.new(sites, {}, outcomes)
    assert_equal expected, result.outcomes
  end
end
