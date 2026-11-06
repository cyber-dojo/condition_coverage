require_relative 'card'
require_relative 'html_statements'
require_relative 'html_tree'
require_relative 'site_tree'
require_relative 'within_methods'

module PathCoverage
  # The cards of one file's page, as Card gives them, in the rail
  # beside its code: a card for each of its methods, and one for
  # each span of its lines holding sites at the top level; each
  # drawn from the card the JSON report lists, as WithinMethods
  # lists them, each site's row with its tree folded under it.
  # It relies on HtmlReport.located to place each tree's rows in
  # the source.
  module HtmlCards
    # The cards of each method of the file at path, parsed as
    # Manifest.parse gives it; site_paths as Result#paths gives
    # them, reached as Recorder#reached does.
    def self.methods(path, parsed, (site_paths, reached))
      source, sites = parsed.values_at(:source, :sites)
      tree = ->(at, top) { fold(source, sites, site_paths, at, top) }
      recorded = [site_paths, reached]
      cards = WithinMethods.listed_in(path, parsed, *recorded)
      cards.map { |site, card| method_card(site, card, &tree) }
    end

    # The Card of the def at site, drawn from card, as
    # WithinMethods.card gives it.
    def self.method_card(site, card, &)
      html = HtmlStatements.card(site, card, &)
      first, column = site.split(':').last(2).map { Integer(_1) }
      status = HtmlStatements.status(card)
      Card.new(first:, last: card['last'], column:, status:,
               top: false, sites: nil, html:)
    end

    # A top card for each span of lines holding sites at the top
    # level of the file at path, outside every def, as each
    # span's lines share one button: a row per site in it, as
    # WithinMethods.listed_tops lists them from operands and
    # site_paths.
    def self.tops(path, parsed, (operands, site_paths))
      source, sites = parsed.values_at(:source, :sites)
      tree = ->(at, top) { fold(source, sites, site_paths, at, top) }
      cards = WithinMethods.listed_tops(path, parsed,
                                        [operands, site_paths])
      cards.map { |site, card| top(site, card, &tree) }
    end

    # The Card of the top card at site, drawn from card.
    def self.top(site, card, &)
      html = HtmlStatements.top_card(site, card, &)
      Card.new(first: card['first'], last: card['last'], column: 0,
               status: HtmlStatements.status(card), top: true,
               sites: card['rows'].size, html:)
    end

    # The rows of site's tree, as a file's page draws them, for
    # its row's fold in a card, headed by top, its row's top, eg
    # if/else, so the two always read the same.
    def self.fold(source, sites, site_paths, site, top)
      condition = sites.fetch(site)
      tree = SiteTree.of(source, condition, site_paths.fetch(site))
      located = HtmlReport.located(source, condition, tree)
      else_at = else_at(source, condition)
      HtmlTree.site_rows(located.merge(else_at:, label: top)).join
    end

    # [line, column, line, column] of condition's else keyword in
    # source, so hovering it can open condition's fold, as
    # hovering its if does; nil for one with no else, or one whose
    # else has no code, or a ?:, whose else is no keyword. The
    # keyword is what comes just before its arm's code, so an
    # elsif, or an else with a comment after it, has none.
    def self.else_at(source, condition)
      return nil if condition.operator == '?:'

      arm = condition.operands.grep(Arm).to_h { [_1.kind, _1] }[:else]
      extent = arm&.extent
      return nil unless extent

      start = source.b.byteslice(0, extent.begin) =~ /\belse\s*\z/
      return nil unless start

      HtmlReport.at(source, start...(start + 4))
    end
  end
end
