module PathCoverage
  # The toggle at the top of every HTML page, picking which paths
  # the pages show: those within each decision, or those within
  # each method. Pages show one or the other, never both.
  module HtmlMode
    # Each mode and its button's label, the first the mode a page
    # starts in.
    MODES = [
      ['decisions', 'Within each decision'],
      ['methods', 'Within each method']
    ].freeze

    # The toggle, a button per mode, the first pressed; empty when
    # methods are not measured, as there is then one mode only.
    def self.toggle(methods)
      return '' unless methods

      buttons = MODES.each_with_index.map do |(mode, label), i|
        %(<button type="button" data-mode="#{mode}") +
          %( aria-pressed="#{i.zero?}">#{label}</button>)
      end
      nav = '<nav class="modes" aria-label="Paths shown">'
      "#{nav}#{buttons.join}</nav>"
    end
  end
end
