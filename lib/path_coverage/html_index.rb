require 'cgi/escape'
require_relative 'html_template'

module PathCoverage
  # The HTML index page: one sortable row per covered file,
  # each linking to that file's own page, then a Total row.
  module HtmlIndex
    # The whole index page: the files table, sortable by any
    # column, with one row per Summary.files row, and total, as
    # Summary.total gives it, as its footer.
    def self.page(rows, total)
      HtmlTemplate.fill(
        HtmlTemplate.asset('index.html'),
        'style' => HtmlTemplate.asset('style.css'),
        'script' => HtmlTemplate.asset('sort.js'),
        'rows' => rows.map { |row| row(row) }.join("\n"),
        'total' => total_row(total),
        'across' => total[:methods] ? ACROSS : ''
      )
    end

    # The heading of the across column, there only when methods
    # are measured.
    ACROSS = '<th class="num" aria-sort="none"><button ' \
             'type="button" data-column="3" data-type="number">' \
             "Across a method's decisions</button></th>".freeze

    # The table row of one Summary.files row; each cell has a
    # data-sort value for the page's column sorting.
    def self.row(row)
      path = CGI.escapeHTML(row[:path])
      link = %(<a href="files/#{path}.html">#{path}</a>)
      "<tr>#{cell(path, link)}#{counts(row).join}</tr>"
    end

    # The footer row: the sums over every file.
    def self.total_row(total)
      "<tr>#{cell('Total', 'Total')}#{counts(total).join}</tr>"
    end

    # The cells after the file's: its sites, then its total
    # within each decision, then, when methods are measured, its
    # total across a method's decisions.
    def self.counts(row)
      cells = [
        cell(row[:sites], row[:sites]),
        paths_cell(row[:decisions])
      ]
      row[:methods] ? cells + [paths_cell(row[:methods])] : cells
    end

    # A cell showing [taken, possible] paths, eg 3 / 6 (50%),
    # sorted by its percent. With no paths to take, as in a file
    # with no method of two or more decisions, it shows -,
    # titled with why, with an empty sort value, which sort.js
    # keeps last whichever way the column is sorted.
    def self.paths_cell(pair)
      taken, possible = pair
      if possible.zero?
        return cell('', '-', 'no method with two or more decisions')
      end

      percent = (100.0 * taken / possible).round
      cell(percent, "#{taken} / #{possible} (#{percent}%)")
    end

    # One table cell, sorted by sort_value, showing content,
    # with title as its hover text when there is one.
    def self.cell(sort_value, content, title = nil)
      hover = title ? %( title="#{title}") : ''
      %(<td data-sort="#{sort_value}"#{hover}>#{content}</td>)
    end
  end
end
