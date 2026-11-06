require 'cgi/escape'
require_relative 'html_syntax'
require_relative 'method_statements'

module PathCoverage
  # One method's card in method mode, hidden in its file's page
  # until side.js moves it into the rail: a title row of the
  # method's name, its complexity, its size and the paths
  # taken, a row titling the columns, then a row per statement,
  # as MethodStatements gives them.
  module HtmlStatements
    # Example: ship, an if then a value, gives its title row,
    # the column titles, then an if row and a value row.
    # The card at site drawn from card, as the JSON report lists
    # it, as WithinMethods.card gives it: its name, its last line,
    # the ways through it and its rows. tree, when given, gives a
    # row's site's tree rows, folded under its row.
    def self.card(site, card, &)
      first, column = site.split(':').last(2)
      rows = card['rows']
      attrs = [
        %(id="paths-#{first}" data-first="#{first}"),
        %(data-col="#{column}" data-last="#{card['last']}"),
        %(data-status="#{status(card)}" hidden="hidden")
      ].join(' ')
      head = title_row(first, card, rows) + columns_row
      %(<div class="#{GRID}" #{attrs}>) +
        %(#{head}#{body(rows, &)}</div>)
    end

    # The classes of every card.
    GRID = 'pathgrid statements'.freeze

    # Example: FEE = (a ? 1 : 0) + (b ? 2 : 0) on line 1, scope
    # file, gives a card titled file, a ?: row each.
    # The card of the sites at the top level whose lines start at
    # site, drawn from card as card draws a def's, its name its
    # scope, eg file or its module, as a method's card is named
    # by its method, its last its lines' last; and marked
    # top-level, as it is no method's: a class no other part of
    # the page has, so no style of another's, eg the header's top
    # line's display, shows it when it is hidden.
    def self.top_card(site, card, &)
      card(site, card, &)
        .sub(%(class="#{GRID}"), %(class="#{GRID} top-level"))
    end

    # Each row's, a site's with the rows tree gives for that site,
    # headed as its row is, folded under it; rows as the JSON
    # report lists a card's.
    def self.body(rows, &tree)
      rows.map do |row|
        site = row['site']
        folded = tree&.call(site, row['top']) if site
        row_of(row, folds: !folded.nil?) + fold(site, folded)
      end.join
    end

    # card's status: covered when every row's taken is known and
    # is all of its paths, and its method was called, if it is a
    # method's; gaps otherwise, as a row not known may have one,
    # and a method never called, even of no rows, ran none of its
    # code.
    def self.status(card)
      rows = card['rows']
      done = rows.all? { |row| row['taken'] == row['paths'] } &&
             card['calls'] != 0
      done ? 'covered' : 'gaps'
    end

    # The row level with the def: card's name and how many times
    # it was called, *its ways, then how many of its rows' paths
    # were not taken, those of rows not known among them, and how
    # many were.
    def self.title_row(first, card, rows)
      seen = rows.map { _1['taken'] }.compact.sum
      paths = rows.map { _1['paths'] }
      cells = [
        "*#{card['ways']}",
        (MethodStatements.size(paths) - seen).to_s, seen.to_s
      ]
      attrs = %(class="prow calls" data-line="#{first}")
      row(attrs, title_label(card), cells)
    end

    # The label of card's title row: its name, escaped, then how
    # many times its method was called.
    def self.title_label(card)
      CGI.escapeHTML(card['name'].to_s) + call_count(card['calls'])
    end

    # Example: 3 as <span class="call-count">&times;3</span>.
    # How many times a method was called, after its name, a gap,
    # never, for 0; none for a top card, or when not known.
    def self.call_count(calls)
      return '' if calls.nil?

      css = calls.zero? ? 'call-count never' : 'call-count'
      %(<span class="#{css}">&times;#{calls}</span>)
    end

    # The row naming the not taken and taken columns.
    def self.columns_row
      cells = ['', 'not taken', 'taken']
      row('class="prow columns"', 'line:col', cells)
    end

    # One statement's row, as the JSON report lists it: its
    # line:column, its at, its top, how many of its paths were
    # not taken, and how many were, ? for both when not known. A
    # site's row is marked as one, so a click on it can open its
    # tree; when it folds a tree, its arrow, left of its
    # line:column, shows whether the fold is open.
    def self.row_of(row, folds: false)
      count = row['taken']
      counts = count ? [row['paths'] - count, count] : %w[? ?]
      cells = [top(row['top']), *counts.map(&:to_s)]
      css = row['site'] ? 'prow site' : 'prow'
      at = row['at']
      attrs = %(class="#{css}" data-line="#{Integer(at[/\d+/])}")
      lead = folds ? arrow(at) : ''
      row(attrs, at, cells, lead)
    end

    # Example: if, a site's top, as <span class="k">if</span>.
    # A row's top, text, coloured as the code pane colours the
    # code it quotes, eg if and return as keywords, as
    # HtmlSyntax.label colours it.
    def self.top(text)
      HtmlSyntax.label(text)
    end

    # The arrow left of the line:column at of a row, its glyph,
    # as style.css draws it, pointing down while its fold is shut
    # and up while it is open.
    def self.arrow(at)
      [
        '<button type="button" class="fold-arrow"',
        ' aria-expanded="false"',
        %( aria-label="Paths of #{at}"></button>)
      ].join
    end

    # Example: 19:04, a statement on line 19 at column 4.
    # statement's line:column, the column two digits so they
    # line up.
    def self.label(statement)
      format('%<line>d:%<column>02d',
             line: statement.line, column: statement.column)
    end

    # The fold under the row of site, hidden until the row is
    # clicked: tree, site's rows as its tree draws them. Empty
    # for a row with no tree.
    def self.fold(site, tree)
      return '' unless tree

      [
        %(<div class="fold" data-site="#{site}"),
        ' hidden="hidden"><div class="site" data-site="">',
        tree, '</div></div>'
      ].join
    end

    # The class each of a row's cells adds after pcell: none for
    # its top, then those colouring not taken and taken.
    CELLS = ['', ' not-taken', ' was-taken'].freeze

    # The class marking a not taken cell of 0, no gap, coloured
    # blue as taken is; none for any other cell, as a count of
    # paths not taken, or one not known, ?, is a gap.
    def self.none(cell, css)
      css == ' not-taken' && cell == '0' ? ' none' : ''
    end

    # A row div with attrs, lead, then its label, then a span
    # per cell.
    def self.row(attrs, label, cells, lead = '')
      spans = cells.zip(CELLS).map do |cell, css|
        %(<span class="pcell#{css}#{none(cell, css)}">#{cell}</span>)
      end
      %(<div #{attrs}>#{lead}<span class="plabel">#{label}</span>) +
        %(#{spans.join}</div>)
    end
  end
end
