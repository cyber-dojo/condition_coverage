require_relative 'condition'
require_relative 'recorder_writes'

module PathCoverage
  # Records the outcome of each instrumented operand.
  class Recorder
    include RecorderWrites

    # One call's way through its method: the outcome of each
    # decision made so far, of the number of decisions its
    # method has.
    Path = Struct.new(:site, :decisions, :outcomes)

    # One evaluation's way through its site: the outcome of
    # each leaf, nil for one not yet, or never, reached.
    Trail = Struct.new(:site, :outcomes)

    # Starts with no outcomes, paths or site paths counted.
    def initialize
      @counts = Hash.new do |counts, key|
        counts[key] = { truthy: 0, falsy: 0 }
      end
      @paths = Hash.new do |paths, site|
        paths[site] = Hash.new(0)
      end
      @site_paths = Hash.new do |site_paths, site|
        site_paths[site] = Hash.new(0)
      end
      @trails_key = :"path_coverage_trails_#{object_id}"
    end

    # The stack of site's evaluations under way in the current
    # thread (fiber), innermost last, so another thread's never
    # mix with its.
    def trails(site)
      stacks = Thread.current[@trails_key] ||=
        Hash.new { |all, key| all[key] = [] }
      stacks[site]
    end

    # { site => { [outcome, ...] => evaluations } } for every
    # evaluation of a site entered and left so far.
    attr_reader :site_paths

    # Starts an evaluation of site, which has size leaves, as
    # the trail its leaves' records fill in.
    def enter(site, size)
      trail = Trail.new(site, Array.new(size))
      trails(site).push(trail)
      trail
    end

    # Ends trail's evaluation, counting its path, and returns
    # value, the site's, unchanged. An evaluation of the same
    # site still entered above trail, as one that raised
    # leaves, took trail's later outcomes, so trail's path is
    # not counted; the stack is cleared down to trail either
    # way.
    def leave(trail, value)
      stack = trails(trail.site)
      clean = stack.last.equal?(trail)
      nil until stack.empty? || stack.pop.equal?(trail)
      @site_paths[trail.site][trail.outcomes] += 1 if clean
      value
    end

    # { method site => { [outcome, ...] => calls } } for every
    # path taken all the way through so far.
    attr_reader :paths

    # A new call's path through the method at site, which has
    # size decisions.
    def path(site, size)
      Path.new(site, size, [])
    end

    # Notes value's outcome as path's index-th decision, counts
    # path once that is its last, or once it is exits, the
    # outcome whose arm leaves the method, and returns value
    # unchanged.
    def decide(path, index, value, exits = nil)
      outcome = value ? true : false
      path.outcomes[index] = outcome
      last = index == path.decisions - 1 || outcome == exits
      @paths[path.site][path.outcomes] += 1 if last
      value
    end

    # The truthy and falsy counts of every operand recorded so
    # far, keyed by [site, index]; an operand that never ran
    # has no entry.
    attr_reader :counts

    # Counts value's outcome and returns it unchanged, so the
    # condition around it behaves exactly as uninstrumented.
    def record(site, index, value)
      outcome = value ? :truthy : :falsy
      @counts[[site, index]][outcome] += 1
      trail = trails(site).last
      trail.outcomes[index] = outcome == :truthy if trail
      value
    end

    # A stand-in for a case's index-th pattern of total: the
    # case matches its subject against the stand-in, which
    # matches it against the pattern, once, as the case would
    # have.
    WhenMatch = Struct.new(
      :recorder, :site, :index, :total, :pattern
    ) do
      # Whether pattern matches subject, exactly as pattern says,
      # noted on the site's path.
      def ===(subject)
        recorder.matched(site, index, total, pattern === subject)
      end
    end

    # The stand-in for pattern, the index-th of size in the case
    # at site.
    def when_match(site, index, size, pattern)
      WhenMatch.new(self, site, index, size, pattern)
    end

    # Notes whether the index-th of size patterns matched, the
    # first entering the case's site, and a match or the last
    # leaving it, as no more patterns are then tried; returns
    # matched unchanged.
    def matched(site, index, size, matched)
      enter(site, size) if index.zero?
      record(site, index, matched)
      last = matched || index == size - 1
      leave(trails(site).last, matched) if last
      matched
    end

    # Starts an evaluation of a stop-early block method's call
    # at site, its block not yet called with any item.
    def enter_items(site)
      trail = enter(site, 2)
      trail.outcomes[0] = ITEMS[0]
      trail
    end

    # Notes value, the block's answer, as its last, and one more
    # item it was called with; returns value unchanged. A block
    # called where its call was not entered, eg in another
    # fiber, is counted but noted on no path.
    def item(site, value)
      trail = trails(site).last
      one_more(trail) if trail
      record(site, 1, value)
    end

    # Notes value, the block's answer for one more item, among
    # all its answers so far: all true, all false, or both;
    # returns value unchanged. A block called where its call
    # was not entered is counted but noted on no path.
    def answer(site, value)
      trail = trails(site).last
      if trail
        one_more(trail)
        now = value ? ANSWERS[0] : ANSWERS[1]
        same = [nil, now].include?(trail.outcomes[1])
        trail.outcomes[1] = same ? now : ANSWERS[2]
      end
      @counts[[site, 1]][value ? :truthy : :falsy] += 1
      value
    end

    # Notes on trail one more item its block was called with.
    def one_more(trail)
      called = ITEMS.index(trail.outcomes[0]) + 1
      trail.outcomes[0] = ITEMS[[called, 2].min]
    end

    # Ends a block method's call, counting its receiver truthy
    # when its block was called, falsy when not, and its path;
    # returns value, the call's, unchanged.
    def leave_items(trail, value)
      called = trail.outcomes[0] != ITEMS[0]
      @counts[[trail.site, 0]][called ? :truthy : :falsy] += 1
      leave(trail, value)
    end
  end
end
