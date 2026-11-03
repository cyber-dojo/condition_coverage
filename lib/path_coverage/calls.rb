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

  # The call rewritten code makes around the pattern of a case
  # nested in site, the site's index-th leaf; returns the
  # pattern's stand-in.
  def self.pattern(site, index, pattern)
    @recorder.pattern(site, index, pattern)
  end

  # The call rewritten code makes around the right side of a
  # write nested in site, its target the site's at-th leaf,
  # outcome being the target's when it runs; returns value
  # unchanged.
  def self.written_at(site, at, outcome, value)
    @recorder.written_at(site, at, outcome, value)
  end

  # The call rewritten code makes around a write nested in site,
  # its target the site's at-th leaf, skipped being the target's
  # outcome when its right side never ran; returns value
  # unchanged.
  def self.settle(site, at, skipped, value)
    @recorder.settle(site, at, skipped, value)
  end

  # The call rewritten code makes before a block method's call
  # nested in site runs, its receiver the site's at-th leaf;
  # returns the site's trail.
  def self.begin_items(site, at)
    @recorder.begin_items(site, at)
  end

  # The call rewritten code makes around the block's expression
  # of a stop-early block method nested in site, its receiver the
  # site's at-th leaf; returns value unchanged.
  def self.item_at(site, at, value)
    @recorder.item_at(site, at, value)
  end

  # The call rewritten code makes around the block's expression
  # of an every-item block method nested in site, its receiver
  # the site's at-th leaf; returns value unchanged.
  def self.answer_at(site, at, value)
    @recorder.answer_at(site, at, value)
  end

  # The call rewritten code makes around a block method's call
  # nested in site, its receiver the site's at-th leaf, with the
  # trail begin_items gave it; returns value unchanged.
  def self.end_items(site, at, trail, value)
    @recorder.end_items(site, at, trail, value)
  end

  # The call rewritten code makes around a &. receiver, the
  # index-th leaf of site, its chain's leaves starting at first;
  # returns value unchanged.
  def self.present(site, index, first, value)
    @recorder.present(site, index, first, value)
  end

  # The call rewritten code makes around a &. chain's value, the
  # index-th leaf of site, its chain's leaves starting at first;
  # returns value unchanged.
  def self.chained(site, index, first, value)
    @recorder.chained(site, index, first, value)
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
