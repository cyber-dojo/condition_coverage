require 'cgi/escape'

module PathCoverage
  # The index page's tab bar, one tab per table: All files,
  # then each group.
  module HtmlTabs
    # The tab bar of names, the first tab selected, each tab
    # controlling the table of the same index.
    def self.bar(names)
      tabs = names.each_with_index.map { |name, i| tab(name, i) }
      nav = %(<nav class="tabs" role="tablist" aria-label="Groups">)
      "#{nav}#{tabs.join}</nav>"
    end

    # The index-th tab, named name.
    def self.tab(name, index)
      selected = index.zero?
      [
        %(<button type="button" role="tab"),
        %( aria-selected="#{selected}"),
        %( aria-controls="files-#{index}">),
        CGI.escapeHTML(name), '</button>'
      ].join
    end
  end
end
