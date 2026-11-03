require_relative 'condition'

module PathCoverage
  # The paths an evaluation of a site can take, worked out
  # from its condition alone: the outcome of each leaf, in leaf
  # order, nil for a leaf that evaluation never reaches.
  module SitePaths
    # Every possible path through site's condition, true
    # before false; a stop-early block method's are fixed by its
    # shape alone.
    def self.possible(site)
      shape = BLOCK_PATHS[site.operator]
      return shape if shape

      walk(site, site.fixed).map do |outcomes, _value|
        site.leaves.map { |range| outcomes[range] }
      end
    end

    # The outcome of an operand on which each operator goes on
    # to its next operand; any other ends the chain there. A
    # when's patterns, and a case's whens, stop at a match.
    CONTINUES_ON = {
      '&&' => true, 'and' => true, '||' => false, 'or' => false,
      'when' => false, 'case' => false
    }.freeze

    # [[{ leaf range => outcome }, value], ...] for each way
    # node can be evaluated, value being the outcome of node as
    # a whole; fixed is the site's { leaf range => its one
    # outcome }. A case is the chain of its whens' conditions.
    def self.walk(node, fixed)
      return leaf(node, fixed) unless node.is_a?(Condition)
      if [*CHOICES, *WRITES].include?(node.operator)
        return ternary(node, fixed)
      end

      if node.operator == 'case'
        whens = node.operands.filter_map(&:body)
        return chain(node.with(operands: whens), fixed)
      end

      chain(node, fixed)
    end

    # The ways a chain of one operator can be evaluated: each
    # way of its first operand, going on to the next while each
    # outcome is the one its operator goes on with.
    def self.chain(node, fixed)
      first, *rest = node.operands
      goes_on = CONTINUES_ON.fetch(node.operator)
      rest.reduce(walk(first, fixed)) do |ways, operand|
        ways.flat_map do |outcomes, value|
          next [[outcomes, value]] unless value == goes_on

          walk(operand, fixed).map do |more, after|
            [outcomes.merge(more), after]
          end
        end
      end
    end

    # The ways a ternary, an if or an unless can be evaluated:
    # each way of its predicate, then each way of the condition
    # the arm it picks is, if that arm is one; one with no else
    # arm picks none. Its value is that of no choice, so is nil.
    def self.ternary(node, fixed)
      predicate, then_arm, else_arm = node.operands
      then_on = THEN_ON[node.operator]
      walk(predicate, fixed).flat_map do |outcomes, value|
        body = (value == then_on ? then_arm : else_arm)&.body
        next [[outcomes, nil]] if body.nil?

        walk(body, fixed).map do |more, _|
          [outcomes.merge(more), nil]
        end
      end
    end

    # The ways a leaf can be evaluated: true, then false, or
    # its one outcome alone when it is fixed.
    def self.leaf(range, fixed)
      only = fixed[range]
      outcomes = only ? [only == :truthy] : [true, false]
      outcomes.map { |outcome| [{ range => outcome }, outcome] }
    end
  end
end
