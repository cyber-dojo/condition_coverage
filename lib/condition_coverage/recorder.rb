module ConditionCoverage
  # Records the outcome of each instrumented operand.
  class Recorder
    # Starts with no outcomes counted.
    def initialize
      @counts = Hash.new do |counts, key|
        counts[key] = { truthy: 0, falsy: 0 }
      end
    end

    # The truthy and falsy counts of every operand recorded so
    # far, keyed by [site, index]; an operand that never ran
    # has no entry.
    attr_reader :counts

    # Counts value's outcome and returns it unchanged, so the &&
    # around it behaves exactly as it would uninstrumented.
    def record(site, index, value)
      outcome = value ? :truthy : :falsy
      @counts[[site, index]][outcome] += 1
      value
    end
  end
end
