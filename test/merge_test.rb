require_relative 'test_helper'
require 'condition_coverage/merge'

class MergeTest < Id58TestBase
  test 'Mg8q10', %w(
  | the operands of several runs merge by adding each
  | operand's true and false counts, keeping a fixed
  | leaf's only, so a gap one run left another can close
  ) do
    first = {
      'source/kata.rb:3:23' => [
        { truthy: 2, falsy: 0 },
        { truthy: 1, falsy: 1 }
      ],
      'source/clock.rb:2:11' => [
        { truthy: 0, falsy: 1 },
        { truthy: 1, falsy: 0, only: :truthy }
      ]
    }
    second = {
      'source/kata.rb:3:23' => [
        { truthy: 0, falsy: 3 },
        { truthy: 0, falsy: 0 }
      ],
      'source/clock.rb:2:11' => [
        { truthy: 4, falsy: 0 },
        { truthy: 0, falsy: 0, only: :truthy }
      ]
    }
    expected = {
      'source/kata.rb:3:23' => [
        { truthy: 2, falsy: 3 },
        { truthy: 1, falsy: 1 }
      ],
      'source/clock.rb:2:11' => [
        { truthy: 4, falsy: 1 },
        { truthy: 1, falsy: 0, only: :truthy }
      ]
    }
    actual = ConditionCoverage::Merge.operands([first, second])
    assert_equal expected, actual
  end
end
