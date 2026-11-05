require_relative 'test_helper'
require 'path_coverage/html_statements'
require 'path_coverage/method_statements'

class HtmlStatementsTest < Id58TestBase
  test 'Hs4q01', %w(
  | Example: ship, an if with only its then taken, its then's
  | call reached, then a value not known
  | Its card is a hidden grid, level with its def, line 1,
  | to its last line, 6.
  | Its title row has its name, its complexity, then how many
  | of its paths were not taken, a row not known counting as
  | not taken, and how many were.
  | Its next row titles its columns.
  | A row's column is two digits, eg 2:02, so they line up.
  | Each row after has its line:column, its top, how many of
  | its paths were not taken, and how many were, ? for both
  | when not known.
  | Not taken is orange, taken blue, as the cells' classes
  | have it; but none not taken, 0, is blue too, as it is no
  | gap.
  | It has a gap, as its if's else was never taken.
  | A site's row is marked as one, to open its tree when
  | clicked.
  | A site's top is coloured as the code it is, as its tree's
  | operator is, eg if as a keyword.
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
    html = card(site, :ship, rows, [1, 1, nil], 6)
    assert_includes html, 'id="paths-1" data-first="1"'
    assert_includes html, 'data-col="0" data-last="6"'
    assert_includes html, 'data-status="gaps" hidden="hidden"'
    assert_includes html, '<div class="prow site" data-line="2">'
    assert_includes html, '<div class="prow" data-line="5">'
    assert_equal [
      ['ship', '*2', '2', '2'],
      ['line:col', '', 'not taken', 'taken'],
      ['2:02', 'if', '1', '1'],
      ['3:04', '()', '0', '1'],
      ['5:02', 'value', '?', '?']
    ], cells(html)
    counts = '<span class="pcell not-taken">1</span>' \
             '<span class="pcell was-taken">1</span>'
    assert_includes html, counts
    none = '<span class="pcell not-taken none">0</span>'
    assert_includes html, none
    top = '<span class="pcell"><span class="k">if</span></span>'
    assert_includes html, top
    assert_includes html, '<span class="pcell">value</span>'
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

  test 'Hs4q03', %w(
  | Example: ship, an if then a value, the if's tree rows given
  | for the if's site, the only site asked for
  | The if's row starts with an arrow, left of its line:col,
  | showing whether its fold is open, as a click on the row
  | opens or closes it.
  | Straight after the if's row is its fold, hidden until
  | then, holding the if's rows as its tree draws them.
  | The rows of the call in its then and of the value are no
  | sites, so have no arrow and no fold.
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
    tree = '<div class="row">if</div>'
    asked = []
    html = card(site, :ship, rows, [1, 1, nil], 6) do |at|
      asked << at
      tree
    end
    assert_equal ['k.rb:2:2'], asked
    order = html.scan(/<div class="(prow[^"]*|fold)"/).flatten
    expected = ['prow calls', 'prow columns', 'prow site'] +
               %w(fold prow prow)
    assert_equal expected, order
    row = [
      '<div class="prow site" data-line="2">',
      '<button type="button" class="fold-arrow"',
      ' aria-expanded="false" aria-label="Paths of 2:02">',
      '</button><span class="plabel">2:02</span>'
    ].join
    assert_includes html, row
    fold = [
      '<div class="fold" data-site="k.rb:2:2" hidden="hidden">',
      %(<div class="site" data-site="">#{tree}</div></div>)
    ].join
    assert_includes html, fold
    assert_includes html, '<div class="prow" data-line="5"><span'
  end

  test 'Hs4q04', %w(
  | Example: install, defining discount, writing rates, then
  | returning
  | Each top that is code is coloured as the code pane colours
  | it: def and return as keywords, = as the pane leaves it.
  | value and (), naming kinds of statement, quote no code, so
  | are plain.
  ) do
    source = <<~RUBY
      def install(rates)
        def discount(total) = total / 2
        @rates = rates
        rates.freeze
        return rates
      end
    RUBY
    site = 'k.rb:1:0'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    html = card(site, :install, rows, [1, 1, 1, 1], 6)
    cell = '<span class="pcell">'
    top = %r{\d+:\d+</span>#{cell}(.*?)</span><span class="pcell n}
    tops = html.scan(top)
    keyword = ->(word) { %(<span class="k">#{word}</span>) }
    expected = [
      keyword.call('def'), '=', '()', keyword.call('return')
    ]
    assert_equal expected, tops.flatten
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
