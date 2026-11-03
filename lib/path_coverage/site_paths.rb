require_relative 'block_paths'
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

      ways = if site.operator == SAFE
               safe(site.operands, nil, site.fixed)
             else
               walk(site, site.fixed)
             end
      ways.map do |outcomes, _value|
        site.leaves.map { |range| outcomes[range] }
      end
    end

    # The ways a &. chain can be evaluated: each receiver not
    # nil going on to the next, a nil one ending the chain, its
    # value false; then, given a last leaf, the chain's value
    # as an operand of a condition, the ways it can be.
    def self.safe(receivers, last, fixed)
      first, *rest = receivers
      on = if !rest.empty? then safe(rest, last, fixed)
           elsif last then walk(last, fixed)
           else [[{}, true]]
           end
      present = on.map do |outcomes, value|
        [outcomes.merge(first => PRESENCE[0]), value]
      end
      [*present, [{ first => PRESENCE[1] }, false]]
    end

    # The outcome of an operand on which each operator goes on
    # to its next operand; any other ends the chain there. A
    # when's patterns, and a case's whens, stop at a match.
    CONTINUES_ON = {
      '&&' => true, 'and' => true, '||' => false, 'or' => false,
      'when' => false, 'case' => false
    }.freeze

    # The operators whose operands are a predicate and arms.
    ARMED = [*CHOICES, *WRITES].freeze

    # [[{ leaf range => outcome }, value], ...] for each way
    # node can be evaluated, value being the outcome of node as
    # a whole; fixed is the site's { leaf range => its one
    # outcome }. A &. chain nested in a condition has its value
    # as its last leaf.
    def self.walk(node, fixed)
      return leaf(node, fixed) unless node.is_a?(Condition)

      send(walker(node.operator), node, fixed)
    end

    # The name of the method that walks a condition named operator:
    # a choice's or a write's arms, a block method's shape, a
    # case's whens, a leaf with sites inside it, a nested &.
    # chain, or a chain of one operator.
    def self.walker(operator)
      return :ternary if ARMED.include?(operator)
      return :block if BLOCK_PATHS.key?(operator)

      WALKERS.fetch(operator, :chain)
    end

    # The walker of each other condition with one of its own.
    WALKERS = {
      'case' => :cases, CONTAINS => :contains, SAFE => :nested_safe
    }.freeze

    # The ways a &. chain nested in a condition can be evaluated,
    # its value its last leaf.
    def self.nested_safe(node, fixed)
      safe(node.operands[0...-1], node.operands.last, fixed)
    end

    # The ways a block method's call nested in a site can be
    # evaluated, fixed by its shape: its receiver's count of items
    # with its block's answers, its value following from them.
    def self.block(node, _fixed)
      BlockPaths.ways(node)
    end

    # The ways a leaf with sites inside it can be evaluated: each
    # way of every one of those sites, which run as it does, then
    # each way of the leaf itself, its value the whole's.
    def self.contains(node, fixed)
      *inner, range = node.operands
      before = inner.reduce([{}]) do |ways, site|
        ways.product(walk(site, fixed)).map do |outcomes, (more, _)|
          outcomes.merge(more)
        end
      end
      ways = before.product(leaf(range, fixed))
      ways.map do |outcomes, (more, value)|
        [outcomes.merge(more), value]
      end
    end

    # The ways a case can be evaluated: as the chain of its
    # whens' conditions.
    def self.cases(node, fixed)
      whens = node.operands.filter_map(&:body)
      chain(node.with(operands: whens), fixed)
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
