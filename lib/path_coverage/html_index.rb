require 'cgi/escape'
require_relative 'html_template'

module PathCoverage
  # The HTML index page: one sortable row per covered file,
  # each linking to that file's own page.
  module HtmlIndex
    # The whole index page: the files table, sortable by any
    # column, with one row per Summary.files row.
    def self.page(rows)
      HtmlTemplate.fill(
        HtmlTemplate.asset('index.html'),
        'style' => HtmlTemplate.asset('style.css'),
        'script' => HtmlTemplate.asset('sort.js'),
        'rows' => rows.map { |row| row(row) }.join("\n")
      )
    end

    # The table row of one Summary.files row; each cell has a
    # data-sort value for the page's column sorting.
    def self.row(row)
      "<tr>#{cells(row).join}</tr>"
    end

    # The four cells: file, sites, outcomes seen, missing.
    def self.cells(row)
      path = CGI.escapeHTML(row[:path])
      link = %(<a href="files/#{path}.html">#{path}</a>)
      seen = "#{row[:seen]} / #{row[:outcomes]} · #{row[:percent]}%"
      [
        cell(path, link),
        cell(row[:sites], row[:sites]),
        cell(row[:percent], seen),
        cell(row[:missing], row[:missing])
      ]
    end

    # One table cell, sorted by sort_value, showing content.
    def self.cell(sort_value, content)
      %(<td data-sort="#{sort_value}">#{content}</td>)
    end
  end
end
