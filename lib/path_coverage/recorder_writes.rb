module PathCoverage
  # The part of the recorder that notes ||= and &&= writes. A
  # write that is a site of its own enters and leaves; one nested
  # in another site notes its target at its place among that
  # site's leaves. It relies on its includer's record, leave and
  # trails.
  module RecorderWrites
    # Notes outcome as the target's of the write at site whose
    # right side ran, false for ||=, true for &&=, and returns
    # value, the right side's, unchanged. The target is never
    # read, as reading it could call a method twice.
    def written(site, outcome, value)
      written_at(site, 0, outcome, value)
    end

    # As written, for a write whose target is site's at-th leaf.
    def written_at(site, at, outcome, value)
      record(site, at, outcome)
      value
    end

    # Ends trail's evaluation of a write, as leave does, its
    # target's outcome skipped when its right side never ran,
    # true for ||=, false for &&=; returns value, the write's,
    # unchanged.
    def leave_write(trail, skipped, value)
      settle(trail.site, 0, skipped, value)
      leave(trail, value)
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
