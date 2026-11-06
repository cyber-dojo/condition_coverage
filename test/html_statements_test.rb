require_relative 'test_helper'
require 'path_coverage/html_statements'
require 'path_coverage/method_statements'
require 'path_coverage/within_methods'

class HtmlStatementsTest < TidTest
  test 'Hs4q01', %w(
  | Example: ship, an if with only its then taken, its then's
  | return reached, then a raise not known
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
          return order.pack
        end
        raise 'unpaid'
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
      ['3:04', 'return', '0', '1'],
      ['5:02', 'raise', '?', '?']
    ], cells(html)
    counts = '<span class="pcell not-taken">1</span>' \
             '<span class="pcell was-taken">1</span>'
    assert_includes html, counts
    none = '<span class="pcell not-taken none">0</span>'
    assert_includes html, none
    top = '<span class="pcell"><span class="k">if</span></span>'
    assert_includes html, top
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
  | Example: ship, an if then a raise, the if's tree rows given
  | for the if's site, the only site asked for
  | The if's row starts with an arrow, left of its line:col,
  | showing whether its fold is open, as a click on the row
  | opens or closes it.
  | Straight after the if's row is its fold, hidden until
  | then, holding the if's rows as its tree draws them.
  | The raise's row is no site, so has no arrow and no fold.
  ) do
    source = <<~RUBY
      def ship(order)
        if order.paid?
          order.pack
        end
        raise 'unpaid'
      end
    RUBY
    site = 'k.rb:1:0'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    tree = '<div class="row">if</div>'
    asked = []
    html = card(site, :ship, rows, [1, nil], 6) do |at|
      asked << at
      tree
    end
    assert_equal ['k.rb:2:2'], asked
    order = html.scan(/<div class="(prow[^"]*|fold)"/).flatten
    expected = ['prow calls', 'prow columns', 'prow site'] +
               %w(fold prow)
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
  | Example: install, an if/else returning rates if frozen,
  | else raising
  | Each top is coloured as the code pane colours it: if, else
  | and return as keywords, if/else each of its words, raise, a
  | call, as the pane leaves it.
  ) do
    source = <<~RUBY
      def install(rates)
        if rates.frozen?
          return rates
        else
          raise 'mutable'
        end
      end
    RUBY
    site = 'k.rb:1:0'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    html = card(site, :install, rows, [1, 1, 1], 7)
    cell = '<span class="pcell">'
    top = %r{\d+:\d+</span>#{cell}(.*?)</span><span class="pcell n}
    tops = html.scan(top)
    keyword = ->(word) { %(<span class="k">#{word}</span>) }
    expected = [
      "#{keyword.call('if')}/#{keyword.call('else')}",
      keyword.call('return'), 'raise'
    ]
    assert_equal expected, tops.flatten
  end

  test 'Hs4q05', %w(
  | Example: a top-level line, FEE = two ?:s, each taken both
  | ways
  | Its card is a top card, titled file, its scope, level with that
  | line and ending there, its rows a ?: each, as a method's
  | card's rows are, each with its fold. Every path of both is
  | taken, so it is covered.
  | It is marked top-level, a class no other part of the page
  | has, so no style of another part shows it when hidden.
  ) do
    source = <<~RUBY
      FEE = (ENV['BIG'] ? 10 : 0) + (ENV['VIP'] ? 5 : 0)
    RUBY
    rows = PathCoverage::MethodStatements.top_rows(source, 'k.rb')
    listed = listed('k.rb:1:0', 'file', rows, [2, 2], 1)
    statements = PathCoverage::HtmlStatements
    html = statements.top_card('k.rb:1:0', listed) do |at|
      %(<div class="row">#{at}</div>)
    end
    open = '<div class="pathgrid statements top-level" id="paths-1"'
    assert_includes html, open
    assert_includes html, 'data-first="1" data-col="0" data-last="1"'
    assert_includes html, 'data-status="covered"'
    assert_equal [
      ['file', '*4', '0', '4'],
      ['line:col', '', 'not taken', 'taken'],
      ['1:18', '?:', '0', '2'],
      ['1:42', '?:', '0', '2']
    ], cells(html)
    assert_includes html, 'data-site="k.rb:1:42"'
  end

  test 'Hs4q06', %w(
  | Example: initialize, a def with no statements, called once,
  | then never called
  | Its card has no rows, so no path it could leave untaken, its
  | title row 0 not taken of 0; its title says how many times
  | it was called, x1, and so it is covered. Never called, x0,
  | it has a gap, so it cannot read as covered.
  ) do
    source = <<~RUBY
      class Shop
        def initialize; end
      end
    RUBY
    site = 'k.rb:2:2'
    rows = PathCoverage::MethodStatements.of(source, 'k.rb')[site]
    actual = [1, 0].map do |calls|
      html = card(site, [:initialize, calls], rows, [], 2)
      [html[/data-status="(\w+)"/, 1], cells(html).first]
    end
    expected = [
      ['covered', ['initialize &times;1', '*1', '0', '0']],
      ['gaps', ['initialize &times;0', '*1', '0', '0']]
    ]
    assert_equal expected, actual
  end

  private

  # The card HtmlStatements draws at site for the card listed
  # gives, with tree.
  def card(site, name, rows, taken, last, &)
    listed = listed(site, name, rows, taken, last)
    PathCoverage::HtmlStatements.card(site, listed, &)
  end

  # The card the JSON report lists at site, named, its name, or
  # [its name, how many times it was called], ending on line
  # last, its rows' taken as taken gives them, its ways its rows'
  # paths multiplied, as one after another: what every card here
  # folds to, none holding another's rows.
  def listed(site, named, rows, taken, last)
    name, calls = Array(named)
    ways = rows.map(&:paths).reduce(1, :*)
    card = [name, last, ways, calls]
    PathCoverage::WithinMethods.card(site, card, rows.zip(taken))
  end

  # The texts of each row of html's grid: its label, then each
  # of its cells; a title's call-count read as part of its label.
  def cells(html)
    rows = html.scan(%r{<div class="prow[^"]*"[^>]*>(.*?)</div>})
    count = %r{<span class="call-count[^>]*>([^<]*)</span>}
    rows.map do |(row)|
      plain = row.sub(count, ' \1')
      plain.scan(%r{<span[^>]*>([^<]*)</span>}).flatten
    end
  end
end
