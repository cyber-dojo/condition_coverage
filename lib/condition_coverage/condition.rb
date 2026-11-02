module ConditionCoverage
  # One site's condition as the manifest found it: its operator
  # and its operands, each the byte range of a leaf or a nested
  # Condition. A site's commands are the byte ranges of its
  # leaves that are command calls, eg `ok? id`; its fixed are
  # { byte range => :truthy } for leaves that can have that one
  # outcome only, eg `Clock.new`. Its extent is the byte range
  # of the whole condition as written, eg a ternary's from its
  # predicate to its else arm, which its leaves alone cannot
  # give.
  Condition = Data.define(
    :operator, :operands, :commands, :fixed, :extent
  ) do
    # A condition with no command-call or fixed leaves, and no
    # extent, by default.
    def initialize(
      operator:, operands:, commands: [], fixed: {}, extent: nil
    )
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
