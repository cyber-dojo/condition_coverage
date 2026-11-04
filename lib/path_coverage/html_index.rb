require 'cgi/escape'
require_relative 'html_index_head'
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
    # there is no tab bar, just the one table. Any operators
    # ignored are named after the tables. Measuring methods, its
    # header holds the mode toggle.
    def self.page(rows, total, groups = [], ignored: [])
      tables = [['All files', rows, total], *groups]
      names = tables.map(&:first)
      HtmlTemplate.page(
        'index.html',
        'modes' => HtmlMode.toggle(!total[:methods].nil?),
        'script' => script(groups),
        'tabs' => groups.empty? ? '' : HtmlTabs.bar(names),
        'tables' => tables_of(tables),
        'ignored' => ignored_line(ignored)
      )
    end

    # The paragraph naming the operators ignored, eg
    # "Ignored: &&="; empty when none are.
    def self.ignored_line(ignored)
      return '' if ignored.empty?

      text = CGI.escapeHTML("Ignored: #{ignored.join(', ')}")
      %(<p class="ignored" data-ignored="">#{text}</p>)
    end

    # Each of tables, [name, rows, total], as the table of its
    # tab.
    def self.tables_of(tables)
      tables.each_with_index.map do |(_, rows, total), index|
        table(index, rows, total)
      end.join("\n")
    end

    # The page's script: its column sorting, with groups its tab
    # switching, then its mode toggle.
    def self.script(groups)
      sort = HtmlTemplate.asset('sort.js')
      tabs = groups.empty? ? '' : HtmlTemplate.asset('tabs.js')
      sort + tabs + HtmlTemplate.asset('mode.js')
    end

    # The index-th tab's table of rows, total as its footer; any
    # but the first starts hidden. Only the first, All files,
    # gives its rows ids, as the others repeat its rows.
    def self.table(index, rows, total)
      anchored = index.zero?
      body = rows.map { |row| row(row, anchored:) }.join("\n")
      head = HtmlIndexHead.of(total[:methods])
      [
        open_tag(index),
        "<thead>\n#{head}\n</thead>",
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
    # data-sort value for the page's column sorting. An anchored
    # row has the id row-<path>, which the file's page links to.
    def self.row(row, anchored: false)
      path = CGI.escapeHTML(row[:path])
      link = %(<a href="files/#{path}.html">#{path}</a>)
      id = anchored ? %( id="row-#{path}") : ''
      "<tr#{id}>#{cell(path, link)}#{counts(row).join}</tr>"
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
        *paths_cells(row[:decisions], 'no decisions', 'decisions')
      ]
      return cells unless row[:methods]

      none = 'no method with two or more decisions'
      cells + paths_cells(row[:methods], none, 'methods')
    end

    # Three cells showing [taken, possible] paths, eg 3, / 6 and
    # 50%, each sorted by its number, so they read 3 / 6 50%,
    # each naming mode, the mode they belong to. With no paths
    # to take, as in a group no file is in, or a file with no
    # method of two or more decisions, the percent shows -,
    # titled with none, saying why, with an empty sort value,
    # which sort.js keeps last whichever way the column is
    # sorted.
    def self.paths_cells(pair, none, mode)
      taken, possible = pair
      counts = [cell(taken, taken, css: 'taken', mode:),
                cell(possible, "/ #{possible}", css: 'of', mode:)]
      none_cell = cell('', '-', none, css: 'percent', mode:)
      return [*counts, none_cell] if possible.zero?

      percent = (100.0 * taken / possible).round
      [*counts, cell(percent, "#{percent}%", css: 'percent', mode:)]
    end

    # One table cell, sorted by sort_value, showing content,
    # with title as its hover text, css as its class and mode as
    # the mode it belongs to, each when there is one.
    def self.cell(sort_value, content, title = nil,
                  css: nil, mode: nil)
      hover = title ? %( title="#{title}") : ''
      klass = css ? %( class="#{css}") : ''
      klass += %( data-mode="#{mode}") if mode
      %(<td#{klass} data-sort="#{sort_value}"#{hover}>#{content}</td>)
    end
  end
end
