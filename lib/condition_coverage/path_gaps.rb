module ConditionCoverage
  # The terminal worklist for paths: one line per path a method
  # never took, and nothing for a method that took them all.
  module PathGaps
    OUTCOMES = [true, false].freeze

    # The gap lines of methods, as PathManifest.methods gives
    # them, for the paths the recorder counted, eg
    # "k.rb:1:0 fee path never taken: line 3 true, line 6 true".
    def self.lines(methods, paths)
      methods.flat_map do |site, method|
        taken = paths.fetch(site, {})
        every = possible(method.decisions)
        every.reject { |path| taken.key?(path) }.map do |path|
          gap = "#{site} #{method.name} path never taken"
          "#{gap}: #{steps(method, path)}"
        end
      end
    end

    # Every path through decisions, true before false at each:
    # one taking a decision's leaving outcome ends there.
    def self.possible(decisions)
      return [[]] if decisions.empty?

      first, *rest = decisions
      OUTCOMES.flat_map do |outcome|
        next [[outcome]] if outcome == first.exits

        possible(rest).map { |tail| [outcome] + tail }
      end
    end

    # path's outcomes, each named by its decision's line.
    def self.steps(method, path)
      path.each_with_index.map do |outcome, index|
        "line #{method.decisions[index].line} #{outcome}"
      end.join(', ')
    end
  end
end
