require_relative 'condition'
require_relative 'rewriter_chains'

module PathCoverage
  # The part of the rewriter that instruments the sites nested in
  # another, eg the &. chain in ok && user&.admin?. The site
  # around them enters and leaves; each nested site's leaves are
  # noted as that site's, at their place among its leaves, by the
  # call its kind needs in place of a plain record.
  module RewriterNested
    # The kinds of nested site whose leaves need a call of their
    # own: a &. chain, a case, a block method's call and a write.
    KINDS = [SAFE, 'case', *BLOCK_PATHS.keys, *WRITES].freeze

    # { leaf range => the opening of its call, nil for none } for
    # the leaves of every site nested in condition that needs a
    # call of its own.
    def self.calls(site, condition)
      leaves = condition.leaves
      nested(condition).reduce({}) do |calls, inner|
        calls.merge(calls_of(site, inner, leaves))
      end
    end

    # The calls for inner's leaves, by its kind.
    def self.calls_of(site, inner, leaves)
      kind = inner.operator
      return RewriterChains.calls(site, inner, leaves) if kind == SAFE

      blocks = BLOCK_PATHS.key?(kind)
      return block_calls(site, inner, leaves) if blocks
      # A write's target is never read, so never wrapped.
      return { inner.operands.first => nil } if WRITES.include?(kind)

      inner.leaves.to_h do |range|
        index = leaves.index(range)
        [range, "PathCoverage.pattern(#{site.inspect}, #{index}, "]
      end
    end

    # The calls for a nested block method's leaves: none for its
    # receiver, whose leaf notes the items its block was called
    # with, and an item or answer call for its block's expression.
    def self.block_calls(site, inner, leaves)
      receiver, body = inner.operands
      at = leaves.index(receiver)
      every = EVERY_ITEM.include?(inner.operator)
      noter = every ? 'answer_at' : 'item_at'
      { receiver => nil,
        body => "PathCoverage.#{noter}(#{site.inspect}, #{at}, " }
    end

    # The inserts, besides its leaves' calls, for every block
    # method's call and write nested in condition.
    def self.inserts(site, condition)
      leaves = condition.leaves
      nested(condition).flat_map do |inner|
        at = leaves.index(inner.operands.first)
        inserts_of(site, inner, at, condition.commands)
      end
    end

    # The inserts for inner, nested at the site's at-th leaf, by
    # its kind: none for a kind whose leaves' calls are enough.
    def self.inserts_of(site, inner, at, commands)
      kind = inner.operator
      return block_inserts(site, inner, at) if BLOCK_PATHS.key?(kind)
      return [] unless WRITES.include?(kind)

      write_inserts(site, inner, at, commands)
    end

    # A nested block method's call wrapped whole, so its items are
    # begun before it runs and counted after; its receiver is the
    # site's at-th leaf.
    def self.block_inserts(site, inner, at)
      name = site.inspect
      begun = "PathCoverage.begin_items(#{name}, #{at})"
      call = "PathCoverage.end_items(#{name}, #{at}, #{begun}, "
      Rewriter.wrap(call, inner.extent, false, 0.5)
    end

    # A nested write, its target the site's at-th leaf: its right
    # side in a written_at call, which notes the target's outcome
    # when it runs, and the whole of it in a settle call, which
    # notes the other when it does not. A right side among
    # commands, eg a command call, is parenthesised.
    def self.write_inserts(site, inner, at, commands)
      _target, arm = inner.operands
      ran = THEN_ON[inner.operator]
      name = site.inspect
      written = "PathCoverage.written_at(#{name}, #{at}, #{ran}, "
      settle = "PathCoverage.settle(#{name}, #{at}, #{!ran}, "
      command = commands.include?(arm.extent)
      Rewriter.wrap(settle, inner.extent, false, 0.5) +
        Rewriter.wrap(written, arm.extent, command, 0)
    end

    # The sites of a kind in KINDS nested in condition, in its
    # operands and in its arms' conditions.
    def self.nested(condition)
      condition.operands.flat_map do |operand|
        case operand
        when Condition
          own = KINDS.include?(operand.operator)
          own ? [operand] : nested(operand)
        when Arm then operand.body ? nested(operand.body) : []
        else []
        end
      end
    end
  end
end
