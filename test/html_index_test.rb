require_relative 'test_helper'
require 'path_coverage/html_index'
require 'rexml/document'

class HtmlIndexTest < Id58TestBase
  test 'zr0H10', %w(
  | Example: kata.rb with decisions [3, 6] and methods [1, 4]
  | Its row links the file to its own page.
  | It shows each total as taken / possible (percent).
  | Eg 3 / 6 (50%) within each decision.
  | Each cell has a data-sort value, the percent for a total,
  | so every column can be sorted.
  ) do
    row = {
      path: 'source/kata.rb', sites: 2, decisions: [3, 6],
      methods: [1, 4]
    }
    html = REXML::Document.new(PathCoverage::HtmlIndex.row(row))
    cells = html.elements.to_a('//td')

    sorts = cells.map { |cell| cell.attributes['data-sort'] }
    assert_equal %w(source/kata.rb 2 50 25), sorts

    texts = cells.map { |cell| text_of(cell) }
    expected = ['source/kata.rb', '2', '3 / 6 (50%)', '1 / 4 (25%)']
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
  | of its four columns.
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
    expected = [
      'File', 'Sites', 'Within each decision',
      "Across a method's decisions"
    ]
    assert_equal(expected, buttons.map { |button| text_of(button) })

    files = html.elements.to_a('//tbody/tr/td[1]')
    expected = ['source/kata.rb', 'source/fee.rb']
    assert_equal(expected, files.map { |cell| text_of(cell) })

    foot = html.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '5', '5 / 10 (50%)', '1 / 4 (25%)']
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

  test 'zr0H50', %w(
  | Example: rows whose methods totals are nil
  | :methods is not measured.
  | So the page has no across column at all.
  | Its headings, rows and Total row have three cells each.
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, decisions: [3, 6],
        methods: nil }
    ]
    total = { sites: 2, decisions: [3, 6], methods: nil }
    page = PathCoverage::HtmlIndex.page(rows, total)
    html = REXML::Document.new(page)
    paths = ['//thead//th', '//tbody/tr/td', '//tfoot/tr/td']
    counts = paths.map { |path| html.elements.to_a(path).size }
    assert_equal [3, 3, 3], counts
  end
end
