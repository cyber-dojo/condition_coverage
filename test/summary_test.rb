require_relative 'test_helper'
require 'path_coverage/path_manifest'
require 'path_coverage/summary'

class SummaryTest < Id58TestBase
  test 'SEye10', %w(
  | Example: kata.rb with two && sites, team.rb with one
  | Each covered file gets one row for the index page.
  | Its sites, eg 2 for kata.rb.
  | Its decisions total as [taken, possible] paths, eg [3, 6].
  | Its methods total is nil, as :methods is not measured.
  ) do
    site_paths = {
      'source/kata.rb:3:23' => [
        { path: [true, true], count: 2 },
        { path: [true, false], count: 0 },
        { path: [false, nil], count: 1 }
      ],
      'source/kata.rb:4:24' => [
        { path: [true, true], count: 1 },
        { path: [true, false], count: 0 },
        { path: [false, nil], count: 0 }
      ],
      'source/team.rb:2:20' => [
        { path: [true, true], count: 1 },
        { path: [true, false], count: 1 },
        { path: [false, nil], count: 4 }
      ]
    }
    expected = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: nil },
      { path: 'source/team.rb', sites: 1, decisions: [3, 3],
        methods: nil }
    ]
    assert_equal expected, PathCoverage::Summary.files(site_paths)
  end

  test 'SEye20', %w(
  | Example: fee.rb's fee with two ifs, called with true then
  | false only, and kata.rb with no method of two decisions
  | :methods is measured, so each row has a methods total.
  | fee.rb's is [1, 4], one of fee's four paths.
  | kata.rb's is [0, 0], as it has no method's paths.
  ) do
    site_paths = {
      'source/fee.rb:4:4' => [
        { path: [true], count: 1 }, { path: [false], count: 0 }
      ],
      'source/fee.rb:7:4' => [
        { path: [true], count: 0 }, { path: [false], count: 1 }
      ],
      'source/kata.rb:3:23' => [
        { path: [true], count: 1 }, { path: [false], count: 1 }
      ]
    }
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
    rows = PathCoverage::Summary.files(site_paths, methods, paths)
    actual = rows.to_h { |row| [row[:path], row[:methods]] }
    expected = {
      'source/fee.rb' => [1, 4], 'source/kata.rb' => [0, 0]
    }
    assert_equal expected, actual
  end

  test 'SEye30', %w(
  | Example: rows for kata.rb and fee.rb
  | The total row adds up each column over every file.
  | Sites 2 + 3 = 5.
  | Decisions [3, 6] + [2, 4] = [5, 10].
  | Methods [0, 0] + [1, 4] = [1, 4].
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: [0, 0] },
      { path: 'source/fee.rb', sites: 3, decisions: [2, 4],
        methods: [1, 4] }
    ]
    expected = { sites: 5, decisions: [5, 10], methods: [1, 4] }
    assert_equal expected, PathCoverage::Summary.total(rows)
  end
end
