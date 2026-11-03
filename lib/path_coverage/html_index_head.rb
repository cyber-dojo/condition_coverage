module PathCoverage
  # The two heading rows of the HTML index's files tables: File
  # and Sites, then each total's name over its taken, / of and %
  # columns, every column sortable.
  module HtmlIndexHead
    # The class and label of each of a total's three columns.
    PARTS = [%w[taken taken], ['of', '/ of'], %w[percent %]].freeze

    # The two heading rows; methods' total only when methods are
    # measured.
    def self.of(methods)
      names = ['Within each decision']
      names << 'Within each method' if methods
      rows = [top_row(names), part_row(names)]
      rows.map { |row| "<tr>\n#{row}\n</tr>" }.join("\n")
    end

    # The first heading row: File and Sites, each over both rows,
    # then each total's name over its three columns.
    def self.top_row(names)
      fixed = [
        heading(' rowspan="2"', 0, 'text', 'File'),
        heading(' class="num" rowspan="2"', 1, 'number', 'Sites')
      ]
      groups = names.map do |name|
        %(<th class="group" colspan="3">#{name}</th>)
      end
      (fixed + groups).join("\n")
    end

    # The second heading row: each total's taken, / of and %.
    def self.part_row(names)
      names.each_index.flat_map do |group|
        PARTS.each_with_index.map do |(css, label), i|
          column = 2 + (3 * group) + i
          heading(%( class="#{css}"), column, 'number', label)
        end
      end.join("\n")
    end

    # A sortable heading, attrs its th's, sorting the column-th
    # column as type, its button showing label.
    def self.heading(attrs, column, type, label)
      data = %(data-column="#{column}" data-type="#{type}")
      button = %(<button type="button" #{data}>#{label}</button>)
      %(<th#{attrs} aria-sort="none">#{button}</th>)
    end
  end
end
