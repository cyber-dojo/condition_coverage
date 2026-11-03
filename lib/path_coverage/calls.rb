# The calls rewritten code makes, each handed to the kernel's
# one recorder. Like the kernel, this file loads before any
# covered file and is never itself instrumented.
module PathCoverage
  # The call rewritten code makes around each operand; returns
  # value unchanged.
  def self.record(site, index, value)
    @recorder.record(site, index, value)
  end

  # The call rewritten code makes before a site's first leaf,
  # site having size leaves; returns the evaluation's trail.
  def self.enter(site, size)
    @recorder.enter(site, size)
  end

  # The call rewritten code makes around a site as a whole,
  # with the trail enter gave it; returns value unchanged.
  def self.leave(trail, value)
    @recorder.leave(trail, value)
  end

  # The call rewritten code makes around a case's pattern, the
  # index-th of size at site; returns the pattern's stand-in.
  def self.when_match(site, index, size, pattern)
    @recorder.when_match(site, index, size, pattern)
  end

  # The call rewritten code makes before a block method's call
  # at site runs; returns the evaluation's trail.
  def self.enter_items(site)
    @recorder.enter_items(site)
  end

  # The call rewritten code makes around a block method's
  # block's expression at site; returns value unchanged.
  def self.item(site, value)
    @recorder.item(site, value)
  end

  # The call rewritten code makes around the block's expression
  # of a block method that calls it with every item; returns
  # value unchanged.
  def self.answer(site, value)
    @recorder.answer(site, value)
  end

  # The call rewritten code makes around a block method's call
  # as a whole, with the trail enter_items gave it; returns
  # value unchanged.
  def self.leave_items(trail, value)
    @recorder.leave_items(trail, value)
  end

  # The call rewritten code makes as a call reaches its
  # method's first decision; returns the call's new path.
  def self.path(site, size)
    @recorder.path(site, size)
  end

  # The call rewritten code makes around each decision's
  # predicate, with exits for one whose arm leaves the method;
  # returns value unchanged.
  def self.decide(path, index, value, exits = nil)
    @recorder.decide(path, index, value, exits)
  end
end
