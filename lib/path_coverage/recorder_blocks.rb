require_relative 'condition'

module PathCoverage
  # The part of the recorder that notes block method calls, eg
  # ids.any? { |id| id.odd? }: how many items the block was called
  # with, as the receiver's leaf, at, and its answers, as the next
  # leaf. A call that is a site of its own enters and leaves; one
  # nested in another site notes at its place among that site's
  # leaves. It relies on its includer's counts, enter, leave,
  # record and trails.
  module RecorderBlocks
    # Starts an evaluation of a block method's call that is a site
    # of its own, its block not yet called with any item.
    def enter_items(site)
      trail = enter(site, 2)
      trail.outcomes[0] = ITEMS[0]
      trail
    end

    # Starts a block method's call nested in site, its receiver the
    # site's at-th leaf, its block not yet called with any item;
    # returns the site's current trail, nil for none.
    def begin_items(site, at)
      trail = trails(site).last
      trail.outcomes[at] = ITEMS[0] if trail
      trail
    end

    # Notes value, the block's answer, as its last, and one more
    # item it was called with; returns value unchanged. A block
    # called where its call was not entered, eg in another
    # fiber, is counted but noted on no path.
    def item(site, value)
      item_at(site, 0, value)
    end

    # As item, for a call whose receiver is site's at-th leaf.
    def item_at(site, at, value)
      trail = trails(site).last
      one_more(trail, at) if trail
      record(site, at + 1, value)
    end

    # Notes value, the block's answer for one more item, among
    # all its answers so far: all true, all false, or both;
    # returns value unchanged. A block called where its call
    # was not entered is counted but noted on no path.
    def answer(site, value)
      answer_at(site, 0, value)
    end

    # As answer, for a call whose receiver is site's at-th leaf.
    def answer_at(site, at, value)
      trail = trails(site).last
      note_answer(trail, at, value) if trail
      @counts[[site, at + 1]][value ? :truthy : :falsy] += 1
      value
    end

    # Notes on trail one more item, and value among the answers
    # so far of the block whose receiver is its at-th leaf.
    def note_answer(trail, at, value)
      one_more(trail, at)
      now = value ? ANSWERS[0] : ANSWERS[1]
      same = [nil, now].include?(trail.outcomes[at + 1])
      trail.outcomes[at + 1] = same ? now : ANSWERS[2]
    end

    # Notes on trail one more item the block whose receiver is its
    # at-th leaf was called with.
    def one_more(trail, at)
      called = ITEMS.index(trail.outcomes[at]) + 1
      trail.outcomes[at] = ITEMS[[called, 2].min]
    end

    # Ends a block method's call that is a site of its own,
    # counting its receiver truthy when its block was called,
    # falsy when not, and its path; returns value, the call's,
    # unchanged.
    def leave_items(trail, value)
      end_items(trail.site, 0, trail, value)
      leave(trail, value)
    end

    # Ends a block method's call whose receiver is site's at-th
    # leaf, counting the receiver truthy when its block was
    # called, falsy when not; returns value unchanged. With no
    # trail, as begin_items found none, it is counted as called.
    def end_items(site, at, trail, value)
      called = trail.nil? || trail.outcomes[at] != ITEMS[0]
      @counts[[site, at]][called ? :truthy : :falsy] += 1
      value
    end
  end
end
