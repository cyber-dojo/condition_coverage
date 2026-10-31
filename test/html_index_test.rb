require_relative 'test_helper'
require 'condition_coverage/html_index'
require 'rexml/document'

class HtmlIndexTest < Id58TestBase
  test 'zr0H10', %w(
  | a summary row becomes one table row on the index page,
  | linking the file to its own page, and giving each cell
  | a data-sort value so every column can be sorted
  ) do
    row = {
      path: 'source/kata.rb', sites: 2, seen: 3, outcomes: 8,
      percent: 38, missing: 5
    }
    html = REXML::Document.new(ConditionCoverage::HtmlIndex.row(row))
    cells = html.elements.to_a('//td')

    sorts = cells.map { |cell| cell.attributes['data-sort'] }
    assert_equal %w(source/kata.rb 2 38 5), sorts

    texts = cells.map { |cell| text_of(cell) }
    assert_equal ['source/kata.rb', '2', '3 / 8 · 38%', '5'], texts

    href = html.elements['//a'].attributes['href']
    assert_equal 'files/source/kata.rb.html', href
  end

  test 'zr0H20', %w(
  | a path with characters special to HTML is escaped,
  | so the row reads, sorts and links as the real path
  ) do
    row = {
      path: 'source/q&a.rb', sites: 1, seen: 4, outcomes: 4,
      percent: 100, missing: 0
    }
    html = REXML::Document.new(ConditionCoverage::HtmlIndex.row(row))

    first = html.elements['//td']
    assert_equal 'source/q&a.rb', first.attributes['data-sort']
    assert_equal 'source/q&a.rb', text_of(first)

    href = html.elements['//a'].attributes['href']
    assert_equal 'files/source/q&a.rb.html', href
  end

  test 'zr0H30', %w(
  | the index page is a table with a sort button heading
  | each of its four columns, and one row per covered file
  ) do
    rows = [
      { path: 'source/kata.rb', sites: 2, seen: 3, outcomes: 8,
        percent: 38, missing: 5 },
      { path: 'source/team.rb', sites: 1, seen: 4, outcomes: 4,
        percent: 100, missing: 0 }
    ]
    html = REXML::Document.new(ConditionCoverage::HtmlIndex.page(rows))

    buttons = html.elements.to_a('//thead//th/button')
    expected = ['File', 'Sites', 'Outcomes seen', 'Missing']
    actual = buttons.map { |button| text_of(button) }
    assert_equal expected, actual

    files = html.elements.to_a('//tbody/tr/td[1]')
    expected = ['source/kata.rb', 'source/team.rb']
    actual = files.map { |cell| text_of(cell) }
    assert_equal expected, actual
  end
end
