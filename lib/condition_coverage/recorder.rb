module ConditionCoverage
  # Records the outcome of each instrumented operand.
  class Recorder
    # One call's way through its method: the outcome of each
    # decision made so far, of the number of decisions its
    # method has.
    Path = Struct.new(:site, :decisions, :outcomes)

    # Starts with no outcomes or paths counted.
    def initialize
      @counts = Hash.new do |counts, key|
        counts[key] = { truthy: 0, falsy: 0 }
      end
      @paths = Hash.new do |paths, site|
        paths[site] = Hash.new(0)
      end
      @outcomes = Hash.new do |outcomes, site|
        outcomes[site] = { truthy: 0, falsy: 0 }
      end
    end

    # The truthy and falsy counts of each site's own outcome,
    # keyed by site; a site that never ran has no entry.
    attr_reader :outcomes

    # Counts value as site's own outcome, eg the predicate
    # deciding a ternary's arm, and returns it unchanged.
    def outcome(site, value)
      @outcomes[site][value ? :truthy : :falsy] += 1
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
      value
    end
  end
end
