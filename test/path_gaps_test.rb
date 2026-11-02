require_relative 'test_helper'
require 'condition_coverage/path_gaps'
require 'condition_coverage/path_manifest'

class PathGapsTest < Id58TestBase
  test 'Pg4w01', %w(
  | one line per path a method never took, each naming the
  | outcome of every decision on it by line, in the order
  | true before false; a method that took every path,
  | here deliver, has no line
  ) do
    decisions = [
      ConditionCoverage::Decision.new(
        line: 3, range: 48...60, command: false
      ),
      ConditionCoverage::Decision.new(
        line: 6, range: 87...97, command: false
      )
    ]
    path_method = ConditionCoverage::PathMethod
    methods = {
      'k.rb:1:0' => path_method.new(
        name: :fee, entry: 45, decisions:
      ),
      'k.rb:11:0' => path_method.new(
        name: :deliver, entry: 210, decisions:
      )
    }
    paths = {
      'k.rb:1:0' => { [true, false] => 2, [false, false] => 1 },
      'k.rb:11:0' => {
        [true, true] => 1, [true, false] => 1,
        [false, true] => 1, [false, false] => 1
      }
    }
    expected = [
      'k.rb:1:0 fee path never taken: line 3 true, line 6 true',
      'k.rb:1:0 fee path never taken: line 3 false, line 6 true'
    ]
    gaps = ConditionCoverage::PathGaps.lines(methods, paths)
    assert_equal expected, gaps
  end

  test 'Pg4w02', %w(
  | a path ends at a decision taking the outcome whose arm
  | leaves the method, so it never names the decisions
  | after it, and is the only path with that outcome there
  ) do
    decisions = [
      ConditionCoverage::Decision.new(
        line: 2, range: 34...47, command: false, exits: true
      ),
      ConditionCoverage::Decision.new(
        line: 3, range: 53...60, command: false
      )
    ]
    methods = {
      'k.rb:1:0' => ConditionCoverage::PathMethod.new(
        name: :fork, entry: 15, decisions:
      )
    }
    paths = { 'k.rb:1:0' => { [false, true] => 3 } }
    expected = [
      'k.rb:1:0 fork path never taken: line 2 true',
      'k.rb:1:0 fork path never taken: line 2 false, line 3 false'
    ]
    gaps = ConditionCoverage::PathGaps.lines(methods, paths)
    assert_equal expected, gaps
  end
end
