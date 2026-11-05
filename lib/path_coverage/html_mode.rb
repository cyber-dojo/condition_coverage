module PathCoverage
  # Which paths an HTML page shows: those within each method, when
  # methods are measured, else those within each decision. A page
  # shows one or the other, never both, and there is no toggle.
  module HtmlMode
    # Each mode and its label, the index's column groups' titles,
    # within each decision first.
    MODES = [
      ['decisions', 'Within each decision'],
      ['methods', 'Within each method']
    ].freeze

    # The html element's attribute naming the mode a page shows:
    # within each method when methods are measured; none when not,
    # as a page with none named shows within each decision.
    def self.attribute(methods)
      methods ? ' data-mode="methods"' : ''
    end
  end
end
