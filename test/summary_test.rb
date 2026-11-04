require_relative 'test_helper'
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
  | Example: fee.rb's fee with two ifs, its card 4 of its 6
  | paths taken, and kata.rb with no def
  | :methods is measured, so each row has a methods total.
  | fee.rb's is [4, 6], fee's card.
  | kata.rb's is [0, 0], as it has no card.
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
    cards = { 'source/fee.rb:2:2' => [4, 6] }
    rows = PathCoverage::Summary.files(site_paths, cards)
    actual = rows.to_h { |row| [row[:path], row[:methods]] }
    expected = {
      'source/fee.rb' => [4, 6], 'source/kata.rb' => [0, 0]
    }
    assert_equal expected, actual
  end

  test 'SEye40', %w(
  | Example: rows for models/kata.rb, models/team.rb, app/fee.rb
  | and lib/zip.rb, with groups Models and App
  | Each group gets the rows whose path matches any of its globs,
  | with their own total.
  | The rows no group matches get a group of their own, Ungrouped.
  ) do
    row = lambda do |path, taken|
      { path:, sites: 1, decisions: [taken, 2], methods: nil }
    end
    kata = row.call('source/models/kata.rb', 1)
    team = row.call('source/models/team.rb', 2)
    fee = row.call('source/app/fee.rb', 0)
    zip = row.call('lib/zip.rb', 2)
    groups = {
      'Models' => ['source/models/**/*.rb'],
      'App' => ['source/app/*.rb', 'source/api/*.rb']
    }
    rows = [kata, team, fee, zip]
    actual = PathCoverage::Summary.groups(rows, groups)
    expected = [
      ['Models', [kata, team],
       { sites: 2, decisions: [3, 4], methods: nil }],
      ['App', [fee], { sites: 1, decisions: [0, 2], methods: nil }],
      ['Ungrouped', [zip],
       { sites: 1, decisions: [2, 2], methods: nil }]
    ]
    assert_equal expected, actual
  end

  test 'SEye41', %w(
  | Example: rows for models/kata.rb and app/fee.rb, with groups
  | Models and App covering both
  | Every row is in a group, so there is no Ungrouped group.
  ) do
    kata = { path: 'source/models/kata.rb', sites: 1,
             decisions: [1, 2], methods: nil }
    fee = { path: 'source/app/fee.rb', sites: 1,
            decisions: [0, 2], methods: nil }
    groups = { 'Models' => ['source/models/*.rb'],
               'App' => ['source/app/*.rb'] }
    found = PathCoverage::Summary.groups([kata, fee], groups)
    assert_equal %w(Models App), found.map(&:first)
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

  test 'SEye50', %w(
  | Example: cards of no file, of fee.rb only, and of fee.rb and
  | kata.rb
  | A file's methods total adds its own defs' cards alone.
  | No cards at all gives [0, 0].
  | fee.rb's two cards, [1, 6] and [2, 6], give [3, 12], whether
  | or not kata.rb has a card too; kata.rb's alone gives [4, 4].
  ) do
    two = { 'src/fee.rb:2:2' => [1, 6], 'src/fee.rb:9:2' => [2, 6] }
    three = two.merge('src/kata.rb:5:2' => [4, 4])
    summary = PathCoverage::Summary
    actual = [
      summary.methods_of('src/kata.rb', {}),
      summary.methods_of('src/fee.rb', two),
      summary.methods_of('src/kata.rb', two),
      summary.methods_of('src/fee.rb', three),
      summary.methods_of('src/kata.rb', three)
    ]
    assert_equal [[0, 0], [3, 12], [0, 0], [3, 12], [4, 4]], actual
  end

  test 'SEye60', %w(
  | Example: a group Models of m/*.rb over no rows, one row in or
  | out of it, two rows in or out of it, and a group with no globs
  | A group lists the rows its globs match, none for no rows.
  | Rows no group matches go to Ungrouped, when there are any.
  | A group with no globs matches no row.
  ) do
    row = lambda do |path|
      { path:, sites: 1, decisions: [1, 2], methods: nil }
    end
    models = { 'Models' => ['m/*.rb'] }
    cases = [
      [[], models],
      [['m/a.rb'], models],
      [['lib/z.rb'], models],
      [%w(m/a.rb m/b.rb), models],
      [%w(lib/y.rb lib/z.rb), models],
      [['m/a.rb'], { 'Empty' => [] }]
    ]
    actual = cases.map do |paths, groups|
      found = PathCoverage::Summary.groups(paths.map(&row), groups)
      found.map { |name, rows, _| [name, rows.map { _1[:path] }] }
    end
    expected = [
      [['Models', []]],
      [['Models', ['m/a.rb']]],
      [['Models', []], ['Ungrouped', ['lib/z.rb']]],
      [['Models', %w(m/a.rb m/b.rb)]],
      [['Models', []], ['Ungrouped', %w(lib/y.rb lib/z.rb)]],
      [['Empty', []], ['Ungrouped', ['m/a.rb']]]
    ]
    assert_equal expected, actual
  end
end
