require_relative 'condition'

module PathCoverage
  # The part of the manifest's visitor that folds every site in one
  # expression into one site. While a leaf is visited, each site
  # found in it, the leaf itself included, is collected as a nested
  # Condition of that leaf, rather than noted as a site of its own.
  # A new scope, eg a block's body or an if's arm, stops the
  # collecting, so a site in it is a site of its own. It relies on
  # its includer's condition_of, chain_condition, safe_chain? and
  # extent_of.
  module ManifestFolding
    # node's Condition as a site nested in a leaf: a &. chain's
    # with its value as its last leaf, as its leaf's outcome
    # follows from it.
    def nested_condition_of(node)
      return chain_condition(node, value: true) if safe_chain?(node)

      condition_of(node)
    end

    # The Conditions of the sites found while yielding, each one
    # collected rather than noted as a site of its own.
    def collected
      outer = @inner
      @inner = []
      yield
      @inner
    ensure
      @inner = outer
    end

    # Yields with no collecting, so a site found is one of its own:
    # for a new scope, eg a block's body or an if's arm.
    def scoped
      outer = @inner
      @inner = nil
      yield
    ensure
      @inner = outer
    end

    # range as a leaf, or, with inner sites found in it, a Condition
    # named contains: those sites, then range, the leaf's outcome.
    # A leaf that is wholly one block method's call whose value
    # follows from its path is that call alone, needing no outcome
    # of its own.
    def contained(inner, range)
      return range if inner.empty?

      only = inner.first
      if inner.size == 1 && only.extent == range &&
         VALUED.include?(only.operator)
        return only
      end

      Condition.new(operator: CONTAINS, operands: [*inner, range],
                    extent: range)
    end

    # A block's body is a new scope: it runs once per item.
    def visit_block_node(node)
      scoped { super }
    end

    # A lambda's body is a new scope: it runs when called.
    def visit_lambda_node(node)
      scoped { super }
    end

    # A def's body is a new scope: it runs when called.
    def visit_def_node(node)
      scoped { super }
    end
  end
end
