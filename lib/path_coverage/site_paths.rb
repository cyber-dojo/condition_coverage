require_relative 'condition'
require_relative 'kinds'

module PathCoverage
  # The paths an evaluation of a site can take, worked out
  # from its condition alone: the outcome of each leaf, in leaf
  # order, nil for a leaf that evaluation never reaches.
  module SitePaths
    # Every possible path through site's condition, true before
    # false, as its kind gives the ways a site of it can be
    # evaluated.
    def self.possible(site)
      ways = Kinds.of(site.operator).root_ways(site, site.fixed)
      ways.map do |outcomes, _value|
        site.leaves.map { |range| outcomes[range] }
      end
    end

    # Example: [false, true, false, true, false] for an any?.
    # site's value on each of its possible paths, in the order
    # possible gives them, nil where not known.
    def self.values(site)
      ways = Kinds.of(site.operator).root_ways(site, site.fixed)
      ways.map(&:last)
    end

    # [[{ leaf range => outcome }, value], ...] for each way
    # node can be evaluated, value being the outcome of node as
    # a whole, as its kind gives them; fixed is the site's
    # { leaf range => its one outcome }.
    def self.walk(node, fixed)
      return leaf(node, fixed) unless node.is_a?(Condition)

      Kinds.of(node.operator).ways(node, fixed)
    end

    # The ways a leaf can be evaluated: true, then false, or
    # its one outcome alone when it is fixed.
    def self.leaf(range, fixed)
      only = fixed[range]
      outcomes = only ? [only == :truthy] : [true, false]
      outcomes.map { |outcome| [{ range => outcome }, outcome] }
    end
  end
end
