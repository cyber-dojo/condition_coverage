module PathCoverage
  # The two coverage totals, each [taken, possible] paths over
  # every covered file. They count the very paths the gap
  # lines list as never taken.
  module Totals
    # Paths within each decision: site_paths, as Result#paths
    # gives them, lists every possible path of each site with
    # its count; one with a count above zero was taken.
    def self.decisions(site_paths)
      every = site_paths.values.flatten
      [every.count { |each| each[:count].positive? }, every.size]
    end

    # Example: cards [4, 6] and [17, 21] give [21, 27].
    # Paths within each method: cards is { def site => [taken,
    # size] }, each method's card's paths taken of its size.
    def self.methods(cards)
      cards.values.reduce([0, 0]) do |(taken, possible), (more, of)|
        [taken + more, possible + of]
      end
    end
  end
end
