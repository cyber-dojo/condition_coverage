require_relative 'test_helper'
require 'path_coverage/path_manifest'
require 'path_coverage/totals'

class TotalsTest < Id58TestBase
  test 'Tq7m10', %w(
  | Example: ok?(id) && new?(id) taken by 2 paths of its 3,
  | and ok?(id) ? :ok : :no taken by both of its 2
  | The decisions total is [taken, possible] over every site.
  | So it is [4, 5].
  | It counts the same paths the gap lines list as never taken.
  ) do
    site_paths = {
      'source/kata.rb:3:23' => [
        { path: [true, true], count: 2 },
        { path: [true, false], count: 0 },
        { path: [false, nil], count: 1 }
      ],
      'source/kata.rb:7:4' => [
        { path: [true], count: 3 },
        { path: [false], count: 1 }
      ]
    }
    assert_equal [4, 5], PathCoverage::Totals.decisions(site_paths)
  end

  test 'Tq7m20', %w(
  | Example: fee with two ifs, called with true then false only
  | Its two decisions have 4 paths together, of which 1 was taken.
  | The methods total is [taken, possible] over every method.
  | So it is [1, 4].
  | It counts the same paths the method gap lines list.
  ) do
    decisions = [4, 7].map do |line|
      PathCoverage::Decision.new(
        line:, range: 0...1, command: false, exits: nil
      )
    end
    fee = PathCoverage::PathMethod.new(
      name: :fee, entry: 0, decisions:
    )
    methods = { 'source/fee.rb:2:2' => fee }
    paths = { 'source/fee.rb:2:2' => { [true, false] => 1 } }
    assert_equal [1, 4], PathCoverage::Totals.methods(methods, paths)
  end
end
