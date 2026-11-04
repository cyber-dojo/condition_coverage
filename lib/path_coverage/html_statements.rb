require 'cgi/escape'
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
    # line.
    def self.card(site, name, rows, taken, last)
      first, column = site.split(':').last(2)
      attrs = [
        %(id="paths-#{first}" data-first="#{first}"),
        %(data-col="#{column}" data-last="#{last}"),
        %(data-status="#{status(rows, taken)}" hidden="hidden")
      ].join(' ')
      body = rows.zip(taken).map { |row, count| row_of(row, count) }
      head = title_row(first, name, rows, taken) + columns_row
      %(<div class="pathgrid statements" #{attrs}>) +
        %(#{head}#{body.join}</div>)
    end

    # covered when every row's taken is known and is all of its
    # paths; gaps otherwise, as a row not known may have one.
    def self.status(rows, taken)
      done = rows.zip(taken).all? { |row, count| count == row.paths }
      done ? 'covered' : 'gaps'
    end

    # The row level with the def: its name, *complexity, then,
    # above paths, its size, and, above taken, the paths taken,
    # those of rows not known left out.
    def self.title_row(first, name, rows, taken)
      cells = [
        "*#{MethodStatements.complexity(rows)}",
        MethodStatements.size(rows).to_s, taken.compact.sum.to_s
      ]
      attrs = %(class="prow calls" data-line="#{first}")
      row(attrs, CGI.escapeHTML(name.to_s), cells)
    end

    # The row naming the paths and taken columns.
    def self.columns_row
      row('class="prow columns"', 'line:col', ['', 'paths', 'taken'])
    end

    # One statement's row: its line:column, the column two
    # digits so they line up, its top, its paths, and how many
    # were taken, ? when not known. A site's row is marked as
    # one, so a click on it can open its tree.
    def self.row_of(statement, count)
      cells = [
        CGI.escapeHTML(statement.top), statement.paths.to_s,
        count.nil? ? '?' : count.to_s
      ]
      label = format('%<line>d:%<column>02d',
                     line: statement.line, column: statement.column)
      css = statement.site ? 'prow site' : 'prow'
      attrs = %(class="#{css}" data-line="#{statement.line}")
      row(attrs, label, cells)
    end

    # A row div with attrs, its label, then a span per cell.
    def self.row(attrs, label, cells)
      spans = cells.map { %(<span class="pcell">#{_1}</span>) }
      %(<div #{attrs}><span class="plabel">#{label}</span>) +
        %(#{spans.join}</div>)
    end
  end
end
