require_relative 'site_paths'

module PathCoverage
  # What a run found: every site the manifest knows of, with
  # the counts its operands were recorded with. Every
  # reporter builds on this.
  class Result
    NEVER_RAN = { truthy: 0, falsy: 0 }.freeze

    # sites is { site => Condition }, from the manifest;
    # counts is { [site, index] => counts } and site_paths is
    # { site => { path => evaluations } }, both from the
    # recorder.
    def initialize(sites, counts, site_paths = {})
      @sites = sites
      @counts = counts
      @site_paths = site_paths
    end

    # { site => [{ path:, count: }, ...] }: every possible path
    # of each site, as SitePaths gives them, with the number of
    # evaluations that took it, zero for one never taken.
    def paths
      @sites.to_h do |site, condition|
        taken = @site_paths.fetch(site, {})
        all = SitePaths.possible(condition).map do |path|
          { path:, count: taken.fetch(path, 0) }
        end
        [site, all]
      end
    end

    # { site => { path => evaluations } } of each path taken
    # that is none of its site's possible paths, eg a &. receiver
    # nil though treated as present; only sites with one. Such a
    # path shows a treatment to be wrong, so it is reported, never
    # dropped.
    def outside
      all = @sites.to_h do |site, condition|
        taken = @site_paths.fetch(site, {})
        [site, taken.except(*SitePaths.possible(condition))]
      end
      all.reject { |_, paths| paths.empty? }
    end

    # The paths taken, as Render.run takes them: site_paths:,
    # as paths gives them, and outside:.
    def taken
      { site_paths: paths, outside: }
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
