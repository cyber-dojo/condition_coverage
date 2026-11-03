require_relative 'condition'

module PathCoverage
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
      if condition.operator == 'case'
        return case_arms(source, condition.operands, outcomes, leaves)
      end

      operands = operands_of(source, condition, outcomes, leaves)
      arms(source, condition, operands, outcomes, leaves)
    end

    # condition's operands' nodes, leaves and nested conditions
    # built in order, its arms left for arms to build after.
    def self.operands_of(source, condition, outcomes, leaves)
      condition.operands.map do |operand|
        case operand
        when Condition then node(source, operand, outcomes, leaves)
        when Arm then operand
        else leaf(source, operand, outcomes, leaves.next)
        end
      end
    end

    # condition's node from its operands' nodes, its ternary
    # arms built in order after its predicate, as each arm's
    # cells follow from the predicate's.
    def self.arms(source, condition, operands, outcomes, leaves)
      predicate = operands.first
      operands = operands.map do |operand|
        next operand unless operand.is_a?(Arm)

        decided = [predicate[:cells], THEN_ON[condition.operator]]
        arm(source, operand, decided, outcomes, leaves)
      end
      cells = value(condition.operator, operands)
      { operator: condition.operator, cells:, operands: }
    end

    # A case's node from its arms, built in order so its whens'
    # patterns pair with path entries left to right: a when is
    # taken on each path one of its patterns matched, and the
    # else on each none did. A case's value is that of no
    # choice, so is nil.
    def self.case_arms(source, arms, outcomes, leaves)
      matched = []
      operands = arms.map do |arm|
        body =
          arm.body ? node(source, arm.body, outcomes, leaves) : nil
        matched << body[:cells].map { |cell| cell == true } if body
        cells = body ? matched.last : unmatched(matched, outcomes)
        { arm: arm.kind, text: text_of(source, arm), cells:, body: }
      end
      { operator: 'case', cells: Array.new(outcomes.size), operands: }
    end

    # An arm's text, nil for one with no statements.
    def self.text_of(source, arm)
      arm.extent ? source.byteslice(arm.extent) : nil
    end

    # Whether each column matched none of its whens' patterns.
    def self.unmatched(matched, outcomes)
      outcomes.each_index.map do |column|
        matched.none? { |taken| taken[column] }
      end
    end

    # One arm of a ternary, an if or an unless: its text, nil
    # for an arm with no statements, whether each column took
    # it, from the predicate's cells and the outcome on which
    # its choice takes its then arm, and the tree of its
    # condition.
    def self.arm(source, arm, (decided, then_on), outcomes, leaves)
      picked = arm.kind == :then ? then_on : !then_on
      body = arm.body ? node(source, arm.body, outcomes, leaves) : nil
      {
        arm: arm.kind, text: text_of(source, arm),
        cells: decided.map { |outcome| outcome == picked }, body:
      }
    end

    # A condition's value in each column: a ternary's or an
    # if's is its taken arm's body's, nil for a plain arm; a
    # chain's is that of the last operand it reached.
    def self.value(operator, operands)
      if CHOICES.include?(operator)
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
