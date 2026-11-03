require_relative 'path_gaps'

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

    # Paths within each method, through its decisions: methods, as
    # PathManifest.methods gives them, each with every path
    # through its decisions; paths, as the recorder counts
    # them, holds the ones taken.
    def self.methods(methods, paths)
      methods.reduce([0, 0]) do |(taken, possible), (site, method)|
        every = PathGaps.possible(method.decisions)
        seen = paths.fetch(site, {})
        [taken + every.count { |path| seen.key?(path) },
         possible + every.size]
      end
    end
  end
end
