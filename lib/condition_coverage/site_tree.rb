require_relative 'condition'

module ConditionCoverage
  # The tree shown under a site's line on its file's page: a
  # grid whose columns are the site's paths, never taken first.
  module SiteTree
    # { operator:, counts:, cells:, operands: } for one site,
    # from its paths, [{path:, count:}, ...]. counts are the
    # columns' counts. Every node has cells, one per column: a
    # leaf { text:, cells: } its outcome, nil where unreached;
    # a condition { operator:, cells:, operands: } its value;
    # an arm { arm:, text:, cells:, body: } whether the column
    # took it, body being its condition's tree, nil for a plain
    # arm. Texts are cut from source at the manifest's ranges.
    def self.of(source, condition, paths)
      columns = paths.sort_by.with_index do |taken, i|
        [taken[:count].zero? ? 0 : 1, i]
      end
      outcomes = columns.map { |taken| taken[:path] }
      tree = node(source, condition, outcomes, (0..).each)
      tree.merge(counts: columns.map { |taken| taken[:count] })
    end

    # The tree of condition, each leaf taking the next index of
    # leaves, so leaves pair with path entries left to right.
    def self.node(source, condition, outcomes, leaves)
      operands = condition.operands.map do |operand|
        case operand
        when Condition then node(source, operand, outcomes, leaves)
        when Arm then operand
        else leaf(source, operand, outcomes, leaves.next)
        end
      end
      arms(source, condition, operands, outcomes, leaves)
    end

    # condition's node from its operands' nodes, its ternary
    # arms built in order after its predicate, as each arm's
    # cells follow from the predicate's.
    def self.arms(source, condition, operands, outcomes, leaves)
      predicate = operands.first
      operands = operands.map do |operand|
        next operand unless operand.is_a?(Arm)

        arm(source, operand, predicate[:cells], outcomes, leaves)
      end
      cells = value(condition.operator, operands)
      { operator: condition.operator, cells:, operands: }
    end

    # One arm of a ternary: whether each column took it, from
    # the predicate's cells, and the tree of its condition.
    def self.arm(source, arm, decided, outcomes, leaves)
      picked = arm.kind == :then
      body = arm.body && node(source, arm.body, outcomes, leaves)
      {
        arm: arm.kind, text: source.byteslice(arm.extent),
        cells: decided.map { |outcome| outcome == picked }, body:
      }
    end

    # A condition's value in each column: a ternary's is its
    # taken arm's body's, nil for a plain arm; a chain's is
    # that of the last operand it reached.
    def self.value(operator, operands)
      if operator == '?:'
        _, *arms = operands
        arms.map { |arm| arm[:body]&.fetch(:cells) }
            .then { |bodies| ternary_value(arms, bodies) }
      else
        operands.map { |operand| operand[:cells] }
                .transpose.map { |column| column.compact.last }
      end
    end

    # Each column's value from the arm it took.
    def self.ternary_value(arms, bodies)
      arms.first[:cells].each_index.map do |column|
        taken = arms.index { |arm| arm[:cells][column] }
        taken && bodies[taken]&.fetch(column)
      end
    end

    # One leaf's text and its outcome in each column.
    def self.leaf(source, range, outcomes, index)
      {
        text: source.byteslice(range),
        cells: outcomes.map { |path| path[index] }
      }
    end
  end
end
