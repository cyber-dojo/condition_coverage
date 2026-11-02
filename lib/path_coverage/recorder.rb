module PathCoverage
  # Records the outcome of each instrumented operand.
  class Recorder
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
  end
end
