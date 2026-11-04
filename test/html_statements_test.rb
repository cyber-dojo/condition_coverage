require_relative 'test_helper'
require 'path_coverage/html_statements'
require 'path_coverage/method_statements'

class HtmlStatementsTest < Id58TestBase
  test 'Hs4q01', %w(
  | Example: ship, an if with only its then taken, then a value
  | Its card is a hidden grid, level with its def, line 1,
  | to its last line, 6.
  | Its title row has its name, its complexity, then, above
  | paths, its size, the sum of its rows' paths, and, above
  | taken, how many of those were taken.
  | Its next row titles its columns.
  | A row's column is two digits, eg 2:02, so they line up.
  | Each row after has its line:column, its top, its paths
  | and how many were taken, ? when not known.
  | It has a gap, as its if's else was never taken.
  | A site's row is marked as one, to open its tree when
  | clicked.
  ) do
    source = <<~RUBY
      def ship(order)
        if order.paid?
          order.pack
        end
        order
      end
    RUBY
    site = 'k.rb:1:0'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    html = card(site, :ship, rows, [1, nil], 6)
    assert_includes html, 'id="paths-1" data-first="1"'
    assert_includes html, 'data-col="0" data-last="6"'
    assert_includes html, 'data-status="gaps" hidden="hidden"'
    assert_includes html, '<div class="prow site" data-line="2">'
    assert_includes html, '<div class="prow" data-line="5">'
    assert_equal [
      ['ship', '*2', '3', '1'],
      ['line:col', '', 'paths', 'taken'],
      ['2:02', 'if', '2', '1'],
      ['5:02', 'value', '1', '?']
    ], cells(html)
  end

  test 'Hs4q02', %w(
  | Example: member?, an endless def of one and chain, all 3
  | of its paths taken
  | Its one row is a site with every path taken, so it is
  | covered.
  ) do
    source = <<~RUBY
      def member?(user) = user[:member] && !user[:banned]
    RUBY
    site = 'k.rb:1:0'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    html = card(site, :member?, rows, [3], 1)
    assert_includes html, 'data-status="covered"'
  end

  private

  # The card HtmlStatements gives for these arguments.
  def card(...)
    PathCoverage::HtmlStatements.card(...)
  end

  # The texts of each row of html's grid: its label, then each
  # of its cells.
  def cells(html)
    rows = html.scan(%r{<div class="prow[^"]*"[^>]*>(.*?)</div>})
    rows.map do |(row)|
      row.scan(%r{<span[^>]*>([^<]*)</span>}).flatten
    end
  end
end
