module ConditionCoverage
  # What a run found: every site the manifest knows of, with
  # the counts its operands were recorded with. Every
  # reporter builds on this.
  class Result
    NEVER_RAN = { truthy: 0, falsy: 0 }.freeze

    # sites is { site => operand ranges }, from the manifest;
    # counts is { [site, index] => counts }, from the recorder.
    def initialize(sites, counts)
      @sites = sites
      @counts = counts
    end

    # { site => [counts of operand 0, counts of operand 1, ...] },
    # with zero counts for an operand that never ran.
    def operands
      @sites.to_h do |site, ranges|
        [site, Array.new(ranges.size) { |i| counts_of(site, i) }]
      end
    end

    private

    # The recorded counts of one operand, or zeros.
    def counts_of(site, index)
      @counts.fetch([site, index], NEVER_RAN)
    end
  end
end
