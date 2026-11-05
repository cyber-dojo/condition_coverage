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
    # The card of the def named name at site, its rows' taken as
    # MethodStatements.taken gives them, last its def's last
    # line. tree, when given, gives a row's site's tree rows,
    # folded under its row.
    def self.card(site, name, rows, taken, last, &)
      first, column = site.split(':').last(2)
      attrs = [
        %(id="paths-#{first}" data-first="#{first}"),
        %(data-col="#{column}" data-last="#{last}"),
        %(data-status="#{status(rows, taken)}" hidden="hidden")
      ].join(' ')
      head = title_row(first, name, rows, taken) + columns_row
      %(<div class="#{GRID}" #{attrs}>) +
        %(#{head}#{body(rows, taken, &)}</div>)
    end

    # The classes of every card.
    GRID = 'pathgrid statements'.freeze

    # Example: FEE = (a ? 1 : 0) + (b ? 2 : 0) on line 1 gives a
    # card titled line 1, a ?: row each.
    # The card of the sites at the top level whose lines start at
    # site, as card gives it, last its lines' last; titled by
    # its line, and marked top-level, as it is no method's: a
    # class no other part of the page has, so no style of
    # another's, eg the header's top line's display, shows it
    # when it is hidden.
    def self.top_card(site, rows, taken, last, &)
      first = site.split(':')[-2]
      card(site, "line #{first}", rows, taken, last, &)
        .sub(%(class="#{GRID}"), %(class="#{GRID} top-level"))
    end

    # Each statement's row, a site's with the rows tree gives
    # for that site folded under it.
    def self.body(rows, taken, &tree)
      rows.zip(taken).map do |row, count|
        site = row.site
        rows = site && tree&.call(site)
        row_of(row, count, folds: !rows.nil?) + fold(row, rows)
      end.join
    end

    # covered when every row's taken is known and is all of its
    # paths; gaps otherwise, as a row not known may have one.
    def self.status(rows, taken)
      done = rows.zip(taken).all? { |row, count| count == row.paths }
      done ? 'covered' : 'gaps'
    end

    # The row level with the def: its name, *complexity, then
    # how many of its paths were not taken, those of rows not
    # known among them, and how many were.
    def self.title_row(first, name, rows, taken)
      seen = taken.compact.sum
      cells = [
        "*#{MethodStatements.complexity(rows)}",
        (MethodStatements.size(rows) - seen).to_s, seen.to_s
      ]
      attrs = %(class="prow calls" data-line="#{first}")
      row(attrs, CGI.escapeHTML(name.to_s), cells)
    end

    # The row naming the not taken and taken columns.
    def self.columns_row
      cells = ['', 'not taken', 'taken']
      row('class="prow columns"', 'line:col', cells)
    end

    # One statement's row: its line:column, the column two
    # digits so they line up, its top, how many of its paths
    # were not taken, and how many were, ? for both when not
    # known. A site's row is marked as one, so a click on it can
    # open its tree; when it folds a tree, its arrow, left of its
    # line:column, shows whether the fold is open.
    def self.row_of(statement, count, folds: false)
      counts = count ? [statement.paths - count, count] : %w[? ?]
      cells = [top(statement), *counts.map(&:to_s)]
      css = statement.site ? 'prow site' : 'prow'
      attrs = %(class="#{css}" data-line="#{statement.line}")
      lead = folds ? arrow(statement) : ''
      row(attrs, label(statement), cells, lead)
    end

    # Example: if, a site's top, as <span class="k">if</span>.
    # statement's top, coloured as the code pane colours the
    # code it quotes, eg if, def and return as keywords; but
    # value and (), which name kinds of statement and quote no
    # code, escaped and plain.
    def self.top(statement)
      text = statement.top
      return CGI.escapeHTML(text) if KINDS.include?(text)

      HtmlSyntax.fragment(text)
    end

    # The tops that name a kind of statement, quoting no code.
    KINDS = %w[value ()].freeze

    # The arrow left of a row's line:column, its glyph, as
    # style.css draws it, pointing down while its fold is shut
    # and up while it is open.
    def self.arrow(statement)
      [
        '<button type="button" class="fold-arrow"',
        ' aria-expanded="false"',
        %( aria-label="Paths of #{label(statement)}"></button>)
      ].join
    end

    # Example: 19:04, a statement on line 19 at column 4.
    # statement's line:column, the column two digits so they
    # line up.
    def self.label(statement)
      format('%<line>d:%<column>02d',
             line: statement.line, column: statement.column)
    end

    # The fold under statement's row, hidden until the row is
    # clicked: tree, its site's rows as its tree draws them.
    # Empty for a row with no tree.
    def self.fold(statement, tree)
      return '' unless tree

      [
        %(<div class="fold" data-site="#{statement.site}"),
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
