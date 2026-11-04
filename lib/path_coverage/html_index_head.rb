require_relative 'html_mode'

module PathCoverage
  # The heading row of the HTML index's files tables: File and
  # Sites, then each mode's total's taken, / of and % columns,
  # every column sortable. The mode toggle names the total the
  # page shows, so no heading names it.
  module HtmlIndexHead
    # The class and label of each of a total's three columns.
    PARTS = [%w[taken taken], ['of', '/ of'], %w[percent %]].freeze

    # The heading row; methods' total only when methods are
    # measured.
    def self.of(methods)
      modes = HtmlMode::MODES.first(methods ? 2 : 1)
      fixed = [
        heading('', 0, 'text', 'File'),
        heading(' class="num"', 1, 'number', 'Sites')
      ]
      "<tr>\n#{(fixed + parts(modes)).join("\n")}\n</tr>"
    end

    # Each mode's total's taken, / of and %, each naming its
    # mode, so the page can show one mode's only.
    def self.parts(modes)
      modes.each_with_index.flat_map do |(mode, _), group|
        PARTS.each_with_index.map do |(css, label), i|
          column = 2 + (3 * group) + i
          attrs = %( class="#{css}" data-mode="#{mode}")
          heading(attrs, column, 'number', label)
        end
      end
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
