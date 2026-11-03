require_relative 'condition'

module PathCoverage
  # The part of the manifest's visitor that builds the sites
  # whose predicate picks an arm: a ternary, named ?:, an if,
  # named if, and an unless, named unless. It relies on its
  # includer's condition_of, extent_of, grouped, leaf and
  # operator?.
  module ManifestChoices
    # The node types whose predicate picks an arm, a ternary
    # being an if_node with no if keyword.
    CHOICE_TYPES = %i[if_node unless_node].freeze

    # Where node's site starts: a &. chain's start; a block
    # method's call at its method; an if's or an unless's
    # keyword, which a modifier's statement comes before;
    # anything else's own start.
    def site_loc(node)
      return node.location if safe_chain?(node)
      return node.message_loc if node.type == :call_node
      return node.location unless CHOICE_TYPES.include?(node.type)
      return node.location if ternary?(node)

      keyword_loc(node)
    end

    # The location of an if's or an unless's keyword.
    def keyword_loc(node)
      unless?(node) ? node.keyword_loc : node.if_keyword_loc
    end

    # True for an unless.
    def unless?(node)
      node.type == :unless_node
    end

    # A ternary, an if or an unless as a Condition.
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

    # An if or an unless as a Condition, named by its keyword,
    # its extent its keyword to the end of its predicate, as its
    # arms are statements, not part of the expression.
    def if_condition(node)
      start = keyword_loc(node).start_offset
      Condition.new(
        operator: unless?(node) ? 'unless' : 'if',
        operands: if_of(node),
        extent: start...node.predicate.location.end_offset
      )
    end

    # An if's or an unless's predicate, then its then arm and,
    # when it has one, its else arm.
    def if_of(node)
      rest = unless?(node) ? node.else_clause : node.subsequent
      [
        predicate_of(node),
        statement_arm(:then, node.statements),
        *else_arm(rest)
      ]
    end

    # An if's arm, statements its code, which never folds into
    # the if's site; as a new scope, any site inside it is a site
    # of its own. An arm with no statements has no extent.
    def statement_arm(kind, statements)
      scoped { statements&.accept(self) }
      extent = statements ? extent_of(statements) : nil
      Arm.new(kind:, extent:, body: nil)
    end

    # An if's else arm, from subsequent: an else's statements,
    # or an elsif, which is a site of its own; none for none.
    def else_arm(subsequent)
      return [] if subsequent.nil?
      if subsequent.type == :else_node
        return [statement_arm(:else, subsequent.statements)]
      end

      scoped { subsequent.accept(self) }
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
    # folds in as its body, being part of the one expression, as
    # does a plain arm with sites inside it, its value its last
    # leaf; a plain arm with none has no body.
    def arm_of(kind, statements)
      written = grouped(statements.body.first)
      extent = extent_of(statements)
      body = if foldable?(written)
               condition_of(written)
             else
               inner = collected { statements.accept(self) }
               inner.empty? ? nil : contained(inner, extent)
             end
      Arm.new(kind:, extent:, body:)
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
    # || nested as a Condition, as is a &. chain, its value its
    # last leaf, anything else a leaf.
    def predicate_of(node)
      predicate = grouped(node.predicate)
      return condition_of(predicate) if operator?(predicate)
      if safe_chain?(predicate)
        return chain_condition(predicate, value: true)
      end

      leaf(predicate)
    end
  end
end
