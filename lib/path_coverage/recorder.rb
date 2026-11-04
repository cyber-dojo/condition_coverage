require_relative 'condition'
require_relative 'recorder_blocks'
require_relative 'recorder_cases'
require_relative 'recorder_chains'
require_relative 'recorder_writes'

module PathCoverage
  # Records the outcome of each instrumented operand.
  class Recorder
    include RecorderBlocks
    include RecorderCases
    include RecorderChains
    include RecorderWrites

    # One evaluation's way through its site: the outcome of
    # each leaf, nil for one not yet, or never, reached.
    Trail = Struct.new(:site, :outcomes)

    # Starts with no outcomes, site paths or reaches counted.
    def initialize
      @counts = Hash.new do |counts, key|
        counts[key] = { truthy: 0, falsy: 0 }
      end
      @site_paths = Hash.new do |site_paths, site|
        site_paths[site] = Hash.new(0)
      end
      @reached = Hash.new(0)
      @trails_key = :"path_coverage_trails_#{object_id}"
    end

    # { name => runs } of each statement reached so far, by its
    # name, eg { "k.rb:2:2" => 2 }; none never reached.
    attr_reader :reached

    # Counts a run of the statement named name.
    def reach(name)
      @reached[name] += 1
      nil
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
  end
end
