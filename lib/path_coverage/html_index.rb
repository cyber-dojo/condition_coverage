require 'cgi/escape'
require_relative 'html_tabs'
require_relative 'html_template'

module PathCoverage
  # The HTML index page: one sortable row per covered file,
  # each linking to that file's own page, then a Total row; with
  # groups, one such table per tab.
  module HtmlIndex
    # The whole index page. rows are Summary.files rows and total
    # their Summary.total. groups are [name, rows, total] for
    # each group, each given a tab after All files; with none
    # there is no tab bar, just the one table.
    def self.page(rows, total, groups = [])
      tables = [['All files', rows, total], *groups]
      names = tables.map(&:first)
      HtmlTemplate.fill(
        HtmlTemplate.asset('index.html'),
        'style' => HtmlTemplate.asset('style.css'),
        'script' => script(groups),
        'tabs' => groups.empty? ? '' : HtmlTabs.bar(names),
        'tables' => tables_of(tables)
      )
    end

    # Each of tables, [name, rows, total], as the table of its
    # tab.
    def self.tables_of(tables)
      tables.each_with_index.map do |(_, rows, total), index|
        table(index, rows, total)
      end.join("\n")
    end

    # The page's script: its column sorting, and, with groups,
    # its tab switching.
    def self.script(groups)
      sort = HtmlTemplate.asset('sort.js')
      groups.empty? ? sort : sort + HtmlTemplate.asset('tabs.js')
    end

    # The headings of the columns every table has.
    HEAD = [
      '<th aria-sort="none"><button type="button" data-column="0" ' \
      'data-type="text">File</button></th>',
      '<th class="num" aria-sort="none"><button type="button" ' \
      'data-column="1" data-type="number">Sites</button></th>',
      '<th class="num" aria-sort="none"><button type="button" ' \
      'data-column="2" data-type="number">Within each decision' \
      '</button></th>'
    ].join("\n").freeze

    # The heading of the methods column, there only when methods
    # are measured.
    METHODS = '<th class="num" aria-sort="none"><button ' \
              'type="button" data-column="3" data-type="number">' \
              'Within each method</button></th>'.freeze

    # The index-th tab's table of rows, total as its footer; any
    # but the first starts hidden.
    def self.table(index, rows, total)
      head = HEAD + (total[:methods] ? "\n#{METHODS}" : '')
      body = rows.map { |row| row(row) }.join("\n")
      [
        open_tag(index),
        "<thead>\n<tr>\n#{head}\n</tr>\n</thead>",
        "<tbody>\n#{body}\n</tbody>",
        "<tfoot>\n#{total_row(total)}\n</tfoot>",
        '</table>'
      ].join("\n")
    end

    # The opening tag of the index-th tab's table, which the tab
    # of the same index controls; any but the first is hidden.
    def self.open_tag(index)
      hidden = index.zero? ? '' : ' hidden="hidden"'
      id = %(id="files-#{index}")
      %(<table class="files" #{id} role="tabpanel"#{hidden}>)
    end

    # The table row of one Summary.files row; each cell has a
    # data-sort value for the page's column sorting.
    def self.row(row)
      path = CGI.escapeHTML(row[:path])
      link = %(<a href="files/#{path}.html">#{path}</a>)
      "<tr>#{cell(path, link)}#{counts(row).join}</tr>"
    end

    # The footer row: the sums over the table's files.
    def self.total_row(total)
      "<tr>#{cell('Total', 'Total')}#{counts(total).join}</tr>"
    end

    # The cells after the file's: its sites, then its total
    # within each decision, then, when methods are measured, its
    # total within each method.
    def self.counts(row)
      cells = [
        cell(row[:sites], row[:sites]),
        paths_cell(row[:decisions], 'no decisions')
      ]
      return cells unless row[:methods]

      none = 'no method with two or more decisions'
      cells + [paths_cell(row[:methods], none)]
    end

    # A cell showing [taken, possible] paths, eg 3 / 6 (50%),
    # sorted by its percent. With no paths to take, as in a group
    # no file is in, or a file with no method of two or more
    # decisions, it shows -, titled with none, saying why, with
    # an empty sort value, which sort.js keeps last whichever
    # way the column is sorted.
    def self.paths_cell(pair, none)
      taken, possible = pair
      return cell('', '-', none) if possible.zero?

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
