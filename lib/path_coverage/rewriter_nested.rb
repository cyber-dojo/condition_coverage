require_relative 'condition'
require_relative 'kinds'

module PathCoverage
  # The part of the rewriter that instruments the sites nested in
  # another, eg the &. chain in ok && user&.admin?. The site
  # around them enters and leaves; each nested site's leaves are
  # noted as that site's, at their place among its leaves, by the
  # calls its kind gives in place of plain records.
  module RewriterNested
    # { leaf range => the opening of its call, nil for none } for
    # the leaves of every site nested in condition whose kind has
    # calls of its own, condition itself included.
    def self.calls(site, condition)
      leaves = condition.leaves
      rooted(condition).reduce({}) do |calls, inner|
        kind = Kinds.of(inner.operator)
        calls.merge(kind.calls(site, inner, leaves))
      end
    end

    # The inserts, besides its leaves' calls, for every site
    # nested in condition whose kind has calls of its own,
    # condition itself included, as its kind gives them.
    def self.inserts(site, condition)
      leaves = condition.leaves
      rooted(condition).flat_map do |inner|
        at = leaves.index(inner.operands.first)
        kind = Kinds.of(inner.operator)
        kind.inserts(site, inner, at, condition.commands)
      end
    end

    # condition alone when its kind has calls of its own, eg a
    # block method's call that is a site of its own, its leaves
    # then noted at their places from 0; else the sites nested in
    # it.
    def self.rooted(condition)
      return [condition] if own_calls?(condition)

      nested(condition)
    end

    # The sites nested in condition whose kind has calls of its
    # own, in its operands and in its arms' conditions.
    def self.nested(condition)
      condition.operands.flat_map do |operand|
        case operand
        when Condition
          own_calls?(operand) ? [operand] : nested(operand)
        when Arm then operand.body ? nested(operand.body) : []
        else []
        end
      end
    end

    # Whether condition's kind gives its leaves calls of their own.
    def self.own_calls?(condition)
      Kinds.of(condition.operator).own_calls?
    end
  end
end
