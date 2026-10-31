module ConditionCoverage
  # One site's condition as the manifest found it: its operator
  # and its operands, each the byte range of a leaf or a nested
  # Condition. A site's commands are the byte ranges of its
  # leaves that are command calls, eg `ok? id`.
  Condition = Data.define(:operator, :operands, :commands) do
    # A condition with no command-call leaves by default.
    def initialize(operator:, operands:, commands: [])
      super
    end

    # The byte range of every leaf operand, left to right; a
    # leaf's index here is the index it is recorded under.
    def leaves
      operands.flat_map do |operand|
        operand.is_a?(Condition) ? operand.leaves : [operand]
      end
    end
  end
end
