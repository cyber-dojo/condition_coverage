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

    # One site paths hash, as Result#paths gives them, each
    # path's count the sum of every run's; runs of the same
    # source list the same paths in the same order.
    def self.paths(runs)
      runs.reduce do |total, run|
        total.merge(run) do |_site, mine, theirs|
          mine.zip(theirs).map do |a, b|
            { path: a[:path], count: a[:count] + b[:count] }
          end
        end
      end
    end

    # One operand's counts from two runs, added; a fixed leaf's
    # only comes from the source, so either run's will do.
    def self.sum(mine, theirs)
      mine.merge(theirs) do |key, a, b|
        key == :only ? a : a + b
      end
    end
  end
end
