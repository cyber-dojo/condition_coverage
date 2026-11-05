require_relative 'html_statements'
require_relative 'html_tree'
require_relative 'method_statements'
require_relative 'site_tree'

module PathCoverage
  # The cards of one file's page, hidden until side.js moves one
  # into the rail: a card for each of its methods, and one for
  # each span of its lines holding sites at the top level; each
  # site's row with its tree folded under it. It relies on
  # HtmlReport.located to place each tree's rows in the source.
  module HtmlCards
    # The cards of each method of the file at path, parsed as
    # Manifest.parse gives it; site_paths as Result#paths gives
    # them, reached as Recorder#reached does.
    def self.methods(path, parsed, (site_paths, reached))
      source, sites = parsed.values_at(:source, :sites)
      names = MethodStatements.names(source, path, sites)
      lasts = MethodStatements.lasts(source, path, sites)
      tree = ->(at) { fold(source, sites, site_paths, at) }
      MethodStatements.of(source, path, sites).map do |site, rows|
        taken = MethodStatements.taken(rows, site_paths, reached)
        HtmlStatements.card(site, names[site], rows, taken,
                            lasts[site], &tree)
      end.join("\n")
    end

    # A top card for each span of lines holding sites at the top
    # level of the file at path, outside every def, as each
    # span's lines share one button: a row per site in it. lines
    # are as SourceLines.of gives them.
    def self.tops(path, parsed, lines, site_paths)
      source, sites = parsed.values_at(:source, :sites)
      tree = ->(at) { fold(source, sites, site_paths, at) }
      spans(path, parsed, lines).map do |span, rows|
        taken = MethodStatements.taken(rows, site_paths)
        site = "#{path}:#{span.begin}:0"
        HtmlStatements.top_card(site, rows, taken, span.end, &tree)
      end.join("\n")
    end

    # { span => its top-level rows } of the file at path, each
    # row under the span its line is in.
    def self.spans(path, parsed, lines)
      source, sites = parsed.values_at(:source, :sites)
      rows = MethodStatements.top_rows(source, path, sites)
      rows.group_by { lines[_1.line - 1][:span] }
    end

    # The rows of site's tree, as a file's page draws them, for
    # its row's fold in a card.
    def self.fold(source, sites, site_paths, site)
      condition = sites.fetch(site)
      tree = SiteTree.of(source, condition, site_paths.fetch(site))
      located = HtmlReport.located(source, condition, tree)
      HtmlTree.site_rows(located).join
    end
  end
end
