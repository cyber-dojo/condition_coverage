module PathCoverage
  # The heading row of the HTML index's files tables: File and
  # Sites, then the taken, / of and % columns of each file's total
  # within each method, every column sortable.
  module HtmlIndexHead
    # The class and label of each of a total's three columns.
    PARTS = [%w[taken taken], ['of', '/ of'], %w[percent %]].freeze

    # The heading row.
    def self.row
      fixed = [
        heading('', 0, 'text', 'File'),
        heading(' class="num"', 1, 'number', 'Sites')
      ]
      parts = PARTS.each_with_index.map do |(css, label), i|
        heading(%( class="#{css}"), 2 + i, 'number', label)
      end
      "<tr>\n#{(fixed + parts).join("\n")}\n</tr>"
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
