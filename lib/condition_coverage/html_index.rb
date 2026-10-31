require 'cgi/escape'

module ConditionCoverage
  # The HTML index page: one sortable row per covered file,
  # each linking to that file's own page.
  module HtmlIndex
    ASSETS = File.join(__dir__, 'html')

    # The whole index page: the files table, sortable by any
    # column, with one row per Summary.files row.
    def self.page(rows)
      fill(
        asset('index.html'),
        'style' => asset('style.css'),
        'script' => asset('sort.js'),
        'rows' => rows.map { |row| row(row) }.join("\n")
      )
    end

    # The text of one of the page's template, style or script
    # files.
    def self.asset(name)
      File.read(File.join(ASSETS, name))
    end

    # template with each {{name}} replaced by values[name].
    def self.fill(template, values)
      template.gsub(/\{\{(\w+)\}\}/) do
        values.fetch(Regexp.last_match(1))
      end
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
