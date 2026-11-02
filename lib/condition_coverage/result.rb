module ConditionCoverage
  # What a run found: every site the manifest knows of, with
  # the counts its operands were recorded with. Every
  # reporter builds on this.
  class Result
    NEVER_RAN = { truthy: 0, falsy: 0 }.freeze

    # sites is { site => Condition }, from the manifest;
    # counts is { [site, index] => counts } and outcomes is
    # { site => counts }, both from the recorder.
    def initialize(sites, counts, outcomes = {})
      @sites = sites
      @counts = counts
      @outcomes = outcomes
    end

    # { site => counts of its own outcome }, with zero counts
    # for a site that never ran, and ternary: true for a
    # ternary, whose outcome picks an arm.
    def outcomes
      @sites.to_h do |site, condition|
        counts = @outcomes.fetch(site, NEVER_RAN)
        ternary = condition.operator == '?:'
        [site, ternary ? counts.merge(ternary: true) : counts]
      end
    end

    # { site => [counts of operand 0, counts of operand 1, ...] },
    # with zero counts for an operand that never ran, and
    # only: naming the one outcome a fixed leaf can have.
    def operands
      @sites.to_h do |site, condition|
        leaves = condition.leaves.each_with_index.map do |range, i|
          leaf(site, condition, range, i)
        end
        [site, leaves]
      end
    end

    private

    # The counts of one leaf, with only: when it is fixed.
    def leaf(site, condition, range, index)
      counts = counts_of(site, index)
      only = condition.fixed[range]
      only ? counts.merge(only:) : counts
    end

    # The recorded counts of one operand, or zeros.
    def counts_of(site, index)
      @counts.fetch([site, index], NEVER_RAN)
    end
  end
end
