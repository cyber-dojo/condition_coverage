module ConditionCoverage
  # One site's condition as the manifest found it: its operator
  # and its operands, each the byte range of a leaf or a nested
  # Condition.
  Condition = Data.define(:operator, :operands) do
    # The byte range of every leaf operand, left to right; a
    # leaf's index here is the index it is recorded under.
    def leaves
      operands.flat_map do |operand|
        operand.is_a?(Condition) ? operand.leaves : [operand]
      end
    end
  end
end
