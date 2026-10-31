module ConditionCoverage
  # The per-file numbers the HTML index page shows.
  module Summary
    # One row per file that has sites in result, in path order.
    def self.files(result)
      by_path = result.operands.group_by { |site, _| path_of(site) }
      by_path.sort.map { |path, sites| row(path, sites) }
    end

    # The summary row of one file's sites.
    def self.row(path, sites)
      operands = sites.flat_map { |_, counts| counts }
      outcomes = operands.size * 2
      seen = operands.sum { |counts| seen_in(counts) }
      {
        path:, sites: sites.size, seen:, outcomes:,
        percent: (100.0 * seen / outcomes).round,
        missing: outcomes - seen
      }
    end

    # How many of an operand's two outcomes were seen.
    def self.seen_in(counts)
      [counts[:truthy], counts[:falsy]].count(&:positive?)
    end

    # The file a site is in: its name minus :line:column.
    def self.path_of(site)
      site.sub(/:\d+:\d+\z/, '')
    end
  end
end
