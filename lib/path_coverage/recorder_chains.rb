require_relative 'condition'

module PathCoverage
  # The part of the recorder that notes &. chains. It relies on
  # its includer's counts, record and trails.
  module RecorderChains
    # Notes value, the index-th leaf of site, a &. receiver, as
    # not nil or nil, and returns it unchanged; it counts truthy
    # when not nil. A receiver after a nil one in its chain,
    # whose leaves start at first, was never reached, as Ruby
    # skips the rest of the chain, so is not noted.
    def present(site, index, first, value)
      return value unless reached?(site, first, index)

      @counts[[site, index]][value.nil? ? :falsy : :truthy] += 1
      trail = trails(site).last
      trail.outcomes[index] = PRESENCE[value.nil? ? 1 : 0] if trail
      value
    end

    # Notes value, a &. chain's value as the index-th leaf of
    # site, as record does, when every receiver of the chain,
    # whose leaves start at first, was not nil; returns value
    # unchanged.
    def chained(site, index, first, value)
      return value unless reached?(site, first, index)

      record(site, index, value)
    end

    # True when site's current evaluation reached its index-th
    # leaf: every leaf of its chain before it, from first, was
    # not nil. An evaluation with no trail, eg in another fiber,
    # is taken to reach it.
    def reached?(site, first, index)
      trail = trails(site).last
      trail.nil? || trail.outcomes[first...index].all?(PRESENCE[0])
    end
  end
end
