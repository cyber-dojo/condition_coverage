require_relative 'card_tree'
require_relative 'manifest'
require_relative 'method_statements'
require_relative 'site_paths'

module PathCoverage
  # The number of ways one call can go through each card, folded
  # over its tree, as CardTree places its rows: rows one after
  # another multiply, as each way through one goes on to each way
  # through the next; a site adds up its paths, each times the
  # ways of the rows it runs on that path; and a row that is the
  # whole of a leaf counts only those of its paths that give the
  # leaf the outcome the path has, so no impossible way is
  # counted where gives knows it. A block's body counts once.
  class CardWays
    # Example: { "k.rb:1:0" => 4 } for def f(a, b), an if of a
    # whose then arm is a ?: of an &&, and whose else is a value.
    # { def site => its ways } for each def in source, its sites
    # those of no settings.
    def self.of(source, path)
      sites = Manifest.sites(source, path)
      cards = MethodStatements.of(source, path, sites)
      cards.transform_values { |rows| card(source, sites, rows) }
    end

    # The ways through a card of rows in source, sites being
    # { site => Condition }, as Manifest.sites gives them.
    def self.card(source, sites, rows)
      places = CardTree.nested(source, sites, rows)
      new(rows, places, sites).total
    end

    # The fold of rows, a card's, placed as places has them, each
    # site row's Condition among sites.
    def initialize(rows, places, sites)
      @rows = rows.to_h { |row| [CardTree.key_of(row), row] }
      @places = places
      @sites = sites
      @children = places.keys.group_by { places[_1]['parent'] }
    end

    # The ways through the card: its top rows' multiplied.
    def total
      tops = @children.fetch(nil, [])
      tops.map { |key| ways_of(key) }.reduce(1, :*)
    end

    # The ways through the row keyed key: 1 for a row that is no
    # site; for a site, its paths' ways added up.
    def ways_of(key)
      site = @rows[key].site
      return 1 unless site

      possible(site).each_index.sum { |path| ways_on(key, path) }
    end

    # The ways through the site row keyed key on its path at
    # index path: the ways of the rows it runs on that path,
    # multiplied, each given that path's outcomes.
    def ways_on(key, path)
      site = @rows[key].site
      outcomes = possible(site)[path]
      running = @children.fetch(key, []).group_by do |child|
        @places[child]['on'].include?(path)
      end
      ways = running.fetch(true, []).map do |child|
        child_ways(child, outcomes)
      end
      ways.reduce(1, :*)
    end

    # The ways through the row keyed child, its parent's path
    # having outcomes: all of them, for a row that gives nothing;
    # else only those of its paths that give its leaf the outcome
    # that path has, or that give what is not known.
    def child_ways(child, outcomes)
      place = @places[child]
      gives = place['gives']
      return ways_of(child) if gives.nil?

      outcome = outcomes[place['leaf']]
      fits = [nil, outcome]
      gives.each_index.sum do |path|
        fits.include?(gives[path]) ? ways_on(child, path) : 0
      end
    end

    # The possible paths of the site named site.
    def possible(site)
      SitePaths.possible(@sites.fetch(site))
    end
  end
end
