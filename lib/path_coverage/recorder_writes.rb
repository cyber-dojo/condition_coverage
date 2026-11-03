module PathCoverage
  # The part of the recorder that notes ||= and &&= writes. It
  # relies on its includer's record and leave.
  module RecorderWrites
    # Notes outcome as the target's of the write at site whose
    # right side ran, false for ||=, true for &&=, and returns
    # value, the right side's, unchanged. The target is never
    # read, as reading it could call a method twice.
    def written(site, outcome, value)
      record(site, 0, outcome)
      value
    end

    # Ends trail's evaluation of a write, as leave does, its
    # target's outcome skipped when its right side never ran,
    # true for ||=, false for &&=; returns value, the write's,
    # unchanged.
    def leave_write(trail, skipped, value)
      record(trail.site, 0, skipped) if trail.outcomes[0].nil?
      leave(trail, value)
    end
  end
end
