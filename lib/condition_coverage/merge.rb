module ConditionCoverage
  # Combines the operands of several runs of the same source.
  module Merge
    # One operands hash, as Result#operands gives them, whose
    # counts are the sums of every run's.
    def self.operands(runs)
      runs.reduce do |total, run|
        total.merge(run) do |_site, mine, theirs|
          mine.zip(theirs).map { |a, b| sum(a, b) }
        end
      end
    end

    # One outcomes hash, as Result#outcomes gives them, whose
    # counts are the sums of every run's.
    def self.outcomes(runs)
      runs.reduce do |total, run|
        total.merge(run) { |_site, mine, theirs| sum(mine, theirs) }
      end
    end

    # Keys whose values come from the source, not the run, so
    # either run's will do.
    FROM_SOURCE = %i[only ternary].freeze

    # One operand's or site's counts from two runs, added; a
    # fixed leaf's only, and a ternary's mark, come from the
    # source, so either run's will do.
    def self.sum(mine, theirs)
      mine.merge(theirs) do |key, a, b|
        FROM_SOURCE.include?(key) ? a : a + b
      end
    end
  end
end
