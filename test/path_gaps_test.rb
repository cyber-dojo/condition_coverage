require_relative 'test_helper'
require 'path_coverage/path_gaps'
require 'path_coverage/path_manifest'

class PathGapsTest < Id58TestBase
  test 'Pg4w01', %w(
  | one line per path a method never took, each naming the
  | outcome of every decision on it by line, in the order
  | true before false; a method that took every path,
  | here deliver, has no line
  ) do
    decisions = [
      PathCoverage::Decision.new(
        line: 3, range: 48...60, command: false
      ),
      PathCoverage::Decision.new(
        line: 6, range: 87...97, command: false
      )
    ]
    path_method = PathCoverage::PathMethod
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
    gaps = PathCoverage::PathGaps.lines(methods, paths)
    assert_equal expected, gaps
  end

  test 'Pg4w02', %w(
  | a path ends at a decision taking the outcome whose arm
  | leaves the method, so it never names the decisions
  | after it, and is the only path with that outcome there
  ) do
    decisions = [
      PathCoverage::Decision.new(
        line: 2, range: 34...47, command: false, exits: true
      ),
      PathCoverage::Decision.new(
        line: 3, range: 53...60, command: false
      )
    ]
    methods = {
      'k.rb:1:0' => PathCoverage::PathMethod.new(
        name: :fork, entry: 15, decisions:
      )
    }
    paths = { 'k.rb:1:0' => { [false, true] => 3 } }
    expected = [
      'k.rb:1:0 fork path never taken: line 2 true',
      'k.rb:1:0 fork path never taken: line 2 false, line 3 false'
    ]
    gaps = PathCoverage::PathGaps.lines(methods, paths)
    assert_equal expected, gaps
  end

  test 'Pg4w03', %w(
  | Example: fee with ifs on lines 3 and 6, never called
  | None of its 4 paths was taken.
  | So each one is a gap line, true before false.
  ) do
    decisions = [3, 6].map do |line|
      PathCoverage::Decision.new(line:, range: 0...1, command: false)
    end
    methods = {
      'k.rb:1:0' => PathCoverage::PathMethod.new(
        name: :fee, entry: 45, decisions:
      )
    }
    never = 'k.rb:1:0 fee path never taken'
    expected = [
      "#{never}: line 3 true, line 6 true",
      "#{never}: line 3 true, line 6 false",
      "#{never}: line 3 false, line 6 true",
      "#{never}: line 3 false, line 6 false"
    ]
    gaps = PathCoverage::PathGaps.lines(methods, {})
    assert_equal expected, gaps
  end
end
