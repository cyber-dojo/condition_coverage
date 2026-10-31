require_relative 'condition'
require_relative 'gaps'

module ConditionCoverage
  # The tree shown under a site's line on its file's page.
  module SiteTree
    # { operator:, operands: [{text:, truthy:, falsy:, gap:}] }
    # for one site, a nested condition being an operand of the
    # same { operator:, operands: } shape. Each leaf has its
    # text cut from source at its manifest byte range, its
    # counts, and its gap label in the same words as the
    # terminal gaps list (nil for none).
    def self.of(source, condition, counts)
      node(source, condition, counts.each)
    end

    # The tree of condition, each leaf taking the next of
    # counts, so leaves pair with counts left to right.
    def self.node(source, condition, counts)
      operands = condition.operands.map do |operand|
        if operand.is_a?(Condition)
          node(source, operand, counts)
        else
          leaf(source, operand, counts.next)
        end
      end
      { operator: condition.operator, operands: }
    end

    # One leaf's text, counts and gap.
    def self.leaf(source, range, counts)
      {
        text: source.byteslice(range),
        truthy: counts[:truthy], falsy: counts[:falsy],
        gap: Gaps.operand_gap(counts).first
      }
    end
  end
end
