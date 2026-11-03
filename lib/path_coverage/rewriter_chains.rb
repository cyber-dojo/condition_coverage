require_relative 'condition'

module PathCoverage
  # The part of the rewriter that instruments &. chains, its
  # inserts spliced in by Rewriter.apply. A receiver is wrapped
  # in a present call, which passes it on unchanged, so it is
  # still evaluated just once.
  module RewriterChains
    # The inserts for a &. chain site: each receiver in a present
    # call, and the whole chain in a leave call that enters it
    # first. Eg user&.account becomes, in effect,
    # leave(enter(site, 1), present(site, 0, 0, user)&.account).
    def self.inserts(site, condition)
      leaves = condition.leaves
      enter = "PathCoverage.enter(#{site.inspect}, #{leaves.size})"
      call = "PathCoverage.leave(#{enter}, "
      command = condition.commands.include?(condition.extent)
      presents = leaves.each_with_index.flat_map do |range, index|
        Rewriter.wrap(present(site, index, 0), range, false, 0)
      end
      presents + Rewriter.wrap(call, condition.extent, command, 1)
    end

    # { leaf range => the opening of its call } for the leaves of
    # chain, a &. chain nested in a site whose leaves are leaves:
    # a receiver's present call, and the chain's value's chained
    # call, each told where its chain's leaves start.
    def self.calls(site, chain, leaves)
      first = leaves.index(chain.operands.first)
      *receivers, value = chain.operands
      calls = receivers.to_h do |range|
        [range, present(site, leaves.index(range), first)]
      end
      calls.merge(value => chained(site, leaves.index(value), first))
    end

    # The opening of the chained call around the index-th leaf
    # of site, a chain's value, its chain's leaves starting at
    # first.
    def self.chained(site, index, first)
      "PathCoverage.chained(#{site.inspect}, #{index}, #{first}, "
    end

    # The opening of the present call around the index-th leaf
    # of site, its chain's leaves starting at first.
    def self.present(site, index, first)
      "PathCoverage.present(#{site.inspect}, #{index}, #{first}, "
    end
  end
end
