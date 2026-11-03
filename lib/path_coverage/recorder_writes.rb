module PathCoverage
  # The part of the recorder that notes ||= and &&= writes: the
  # target's outcome at its place among its site's leaves, at 0
  # for a write that is a site of its own. It relies on its
  # includer's record and trails.
  module RecorderWrites
    # Notes outcome as the target's, site's at-th leaf, of the
    # write whose right side ran, false for ||=, true for &&=,
    # and returns value, the right side's, unchanged. The target
    # is never read, as reading it could call a method twice.
    def written_at(site, at, outcome, value)
      record(site, at, outcome)
      value
    end

    # Notes skipped as the outcome of the write's target, site's
    # at-th leaf, when its right side never ran, so noted none;
    # returns value, the write's, unchanged.
    def settle(site, at, skipped, value)
      trail = trails(site).last
      unnoted = trail.nil? || trail.outcomes[at].nil?
      record(site, at, skipped) if unnoted
      value
    end
  end
end
