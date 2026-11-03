require_relative 'test_helper'
require 'path_coverage/html_index'
require 'rexml/document'

class HtmlIndexTest < Id58TestBase
  test 'zr0H10', %w(
  | Example: kata.rb with decisions [3, 6] and methods [1, 4]
  | Its row links the file to its own page.
  | It shows each total as three cells: taken, / possible, and
  | percent, so it still reads 3 / 6 50%.
  | Each cell has a data-sort value, its number, so every
  | column can be sorted, eg by possible paths alone.
  ) do
    row = {
      path: 'source/kata.rb', sites: 2, decisions: [3, 6],
      methods: [1, 4]
    }
    html = REXML::Document.new(PathCoverage::HtmlIndex.row(row))
    cells = html.elements.to_a('//td')

    sorts = cells.map { |cell| cell.attributes['data-sort'] }
    assert_equal %w(source/kata.rb 2 3 6 50 1 4 25), sorts

    texts = cells.map { |cell| text_of(cell) }
    expected = ['source/kata.rb', '2', '3', '/ 6', '50%',
                '1', '/ 4', '25%']
    assert_equal expected, texts

    href = html.elements['//a'].attributes['href']
    assert_equal 'files/source/kata.rb.html', href
  end

  test 'zr0H20', %w(
  | Example: source/q&a.rb
  | A path with characters special to HTML is escaped.
  | So the row reads, sorts and links as the real path.
  ) do
    row = {
      path: 'source/q&a.rb', sites: 1, decisions: [2, 2],
      methods: nil
    }
    html = REXML::Document.new(PathCoverage::HtmlIndex.row(row))

    first = html.elements['//td']
    assert_equal 'source/q&a.rb', first.attributes['data-sort']
    assert_equal 'source/q&a.rb', text_of(first)

    href = html.elements['//a'].attributes['href']
    assert_equal 'files/source/q&a.rb.html', href
  end

  test 'zr0H30', %w(
  | Example: rows for kata.rb and fee.rb, and their total
  | The index page is a table with a sort button heading each
  | of its columns.
  | Within each decision and Within each method each head three:
  | taken, / of, and the percent.
  | It has one row per covered file.
  | Its footer is the Total row, which sorting leaves last.
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: [0, 0] },
      { path: 'source/fee.rb', sites: 3, decisions: [2, 4],
        methods: [1, 4] }
    ]
    total = { sites: 5, decisions: [5, 10], methods: [1, 4] }
    page = PathCoverage::HtmlIndex.page(rows, total)
    html = REXML::Document.new(page)

    buttons = html.elements.to_a('//thead//th/button')
    expected = ['File', 'Sites', 'taken', '/ of', '%',
                'taken', '/ of', '%']
    assert_equal(expected, buttons.map { |button| text_of(button) })

    groups = html.elements.to_a('//thead//th[@colspan="3"]')
    expected = ['Within each decision', 'Within each method']
    assert_equal(expected, groups.map { |group| text_of(group) })

    files = html.elements.to_a('//tbody/tr/td[1]')
    expected = ['source/kata.rb', 'source/fee.rb']
    assert_equal(expected, files.map { |cell| text_of(cell) })

    foot = html.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '5', '5', '/ 10', '50%', '1', '/ 4', '25%']
    assert_equal(expected, foot.map { |cell| text_of(cell) })
  end

  test 'zr0H40', %w(
  | Example: a methods total of [0, 0]
  | The file has no method of two or more decisions.
  | There is no percent, so the cell shows -.
  | Its title says why.
  | Its data-sort is empty, which sort.js keeps last in both
  | directions, so the lowest percent can still sort first.
  ) do
    row = {
      path: 'source/kata.rb', sites: 1, decisions: [1, 2],
      methods: [0, 0]
    }
    html = REXML::Document.new(PathCoverage::HtmlIndex.row(row))
    cell = html.elements.to_a('//td').last
    actual = %w(data-sort title).map { cell.attributes[_1] }
    expected = ['', 'no method with two or more decisions']
    assert_equal [expected, '-'], [actual, text_of(cell)]
  end

  test 'zr0H60', %w(
  | Example: kata.rb and fee.rb, with a group 'Models' of fee.rb
  | The page has a tab for All files, then one per group.
  | Each tab has a table of its own files, with its own Total.
  | Only the first tab's table shows; the others are hidden.
  | With no groups there is no tab bar, just the one table.
  ) do
    kata = { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
             methods: nil }
    fee = { path: 'source/fee.rb', sites: 3, decisions: [2, 4],
            methods: nil }
    all = { sites: 5, decisions: [5, 10], methods: nil }
    models = { sites: 3, decisions: [2, 4], methods: nil }
    page = PathCoverage::HtmlIndex.page(
      [kata, fee], all, [['Models', [fee], models]]
    )
    html = REXML::Document.new(page)
    tabs = html.elements.to_a("//*[@role='tab']")
    assert_equal(['All files', 'Models'], tabs.map { text_of(_1) })
    tables = html.elements.to_a('//table')
    actual = tables.map do |table|
      cells = table.elements.to_a('tbody/tr/td[1]')
      files = cells.map { text_of(_1) }
      cells = (3..5).map { table.elements["tfoot/tr/td[#{_1}]"] }
      total = cells.map { text_of(_1) }.join(' ')
      [files, total, table.attributes['hidden']]
    end
    expected = [
      [['source/kata.rb', 'source/fee.rb'], '5 / 10 50%', nil],
      [['source/fee.rb'], '2 / 4 50%', 'hidden']
    ]
    assert_equal expected, actual
    page = PathCoverage::HtmlIndex.page([kata], all)
    plain = REXML::Document.new(page)
    tab_count = plain.elements.to_a("//*[@role='tab']").size
    table_count = plain.elements.to_a('//table').size
    assert_equal [0, 1], [tab_count, table_count]
  end

  test 'zr0H50', %w(
  | Example: rows whose methods totals are nil
  | :methods is not measured.
  | So the page has no methods columns at all.
  | Its sort buttons, rows and Total row have five cells each:
  | File, Sites, and taken, / of and % within each decision.
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: nil }
    ]
    total = { sites: 2, decisions: [3, 6], methods: nil }
    page = PathCoverage::HtmlIndex.page(rows, total)
    html = REXML::Document.new(page)
    paths = ['//thead//button', '//tbody/tr/td', '//tfoot/tr/td']
    counts = paths.map { |path| html.elements.to_a(path).size }
    assert_equal [5, 5, 5], counts
  end

  test 'zr0H70', %w(
  | Example: an index with &&= and ||= ignored
  | After its tables the page names the operators ignored, so
  | its totals never pass for ones that measured them.
  | With none ignored it names none.
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: nil }
    ]
    total = { sites: 2, decisions: [3, 6], methods: nil }
    index = PathCoverage::HtmlIndex
    page = index.page(rows, total, ignored: ['&&=', '||='])
    html = REXML::Document.new(page)
    named = html.elements.to_a('//*[@data-ignored]')
    assert_equal(['Ignored: &&=, ||='], named.map { text_of(_1) })
    plain = REXML::Document.new(index.page(rows, total))
    assert_equal [], plain.elements.to_a('//*[@data-ignored]')
  end
end
