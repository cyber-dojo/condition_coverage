require_relative 'condition'

module PathCoverage
  # The part of the manifest's visitor that builds the sites
  # whose predicate picks an arm: a ternary, named ?:, and an
  # if, named if. It relies on its includer's condition_of,
  # extent_of, grouped, leaf and operator?.
  module ManifestChoices
    # True for a modifier if, eg `return if done?`, whose
    # statement comes before its if keyword.
    def modifier?(node)
      return false if ternary?(node) || node.statements.nil?

      node.statements.location.start_offset <
        node.if_keyword_loc.start_offset
    end

    # A ternary or an if as a Condition.
    def choice_of(node)
      ternary?(node) ? ternary_condition(node) : if_condition(node)
    end

    # A ternary as a Condition, its extent the whole of it.
    def ternary_condition(node)
      Condition.new(
        operator: '?:', operands: ternary_of(node),
        extent: extent_of(node)
      )
    end

    # An if as a Condition, its extent its if keyword to the end
    # of its predicate, as its arms are statements, not part of
    # the expression.
    def if_condition(node)
      start = node.if_keyword_loc.start_offset
      Condition.new(
        operator: 'if', operands: if_of(node),
        extent: start...node.predicate.location.end_offset
      )
    end

    # An if's predicate, then its then arm and, when it has
    # one, its else arm.
    def if_of(node)
      [
        predicate_of(node),
        statement_arm(:then, node.statements),
        *else_arm(node.subsequent)
      ]
    end

    # An if's arm, statements its code, which never folds into
    # the if's site; any site inside it is a site of its own.
    # An arm with no statements has no extent.
    def statement_arm(kind, statements)
      statements&.accept(self)
      extent = statements && extent_of(statements)
      Arm.new(kind:, extent:, body: nil)
    end

    # An if's else arm, from subsequent: an else's statements,
    # or an elsif, which is a site of its own; none for none.
    def else_arm(subsequent)
      return [] if subsequent.nil?
      if subsequent.type == :else_node
        return [statement_arm(:else, subsequent.statements)]
      end

      subsequent.accept(self)
      extent = extent_of(subsequent)
      [Arm.new(kind: :else, extent:, body: nil)]
    end

    # A ternary's predicate, then its then and else arms.
    def ternary_of(node)
      [
        predicate_of(node),
        arm_of(:then, node.statements),
        arm_of(:else, node.subsequent.statements)
      ]
    end

    # One arm of a ternary, statements its code: a condition
    # folds in as its body, being part of the one expression;
    # any site inside a plain arm is a site of its own.
    def arm_of(kind, statements)
      written = grouped(statements.body.first)
      body = condition_of(written) if foldable?(written)
      statements.accept(self) if body.nil?
      Arm.new(kind:, extent: extent_of(statements), body:)
    end

    # True for a condition that folds into a ternary's site:
    # an &&, ||, and, or, or a ternary.
    def foldable?(node)
      operator?(node) || ternary?(node)
    end

    # True for a ternary, an if with no if keyword.
    def ternary?(node)
      node.type == :if_node && node.if_keyword_loc.nil?
    end

    # A ternary's or an if's predicate as its operand: an && or
    # || nested as a Condition, anything else a leaf.
    def predicate_of(node)
      predicate = node.predicate
      return condition_of(predicate) if operator?(predicate)

      leaf(predicate)
    end
  end
end
