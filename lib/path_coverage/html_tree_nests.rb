require_relative 'condition'

module PathCoverage
  # The rows HtmlTree draws for the nodes that nest under a leaf
  # rather than branch from an operator: a &. chain's receivers,
  # and the sites inside a leaf.
  module HtmlTreeNests
    # The rows of a &. chain's leaves, each under the one before,
    # as each is reached only when the one before is not nil.
    def self.chain_rows(chain, indent)
      chain[:operands].each_with_index.map do |operand, depth|
        HtmlTree.operand_row(operand, "#{indent}#{'   ' * depth}└─ ")
      end
    end

    # operands with each leaf that has sites inside it unfolded
    # into those sites, then the leaf, as siblings, so each site's
    # rows are drawn once, eg select then ….any?.
    def self.unfolded(operands)
      operands.flat_map do |operand|
        inside = operand[:operator] == CONTAINS
        inside ? operand[:operands] : [operand]
      end
    end
  end
end
