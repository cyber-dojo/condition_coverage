require_relative 'condition'
require_relative 'site'
require_relative 'site_paths'

module PathCoverage
  # The part of the manifest's visitor that folds every site in one
  # expression into one site. While a leaf is visited, each site
  # found in it, the leaf itself included, is collected as a nested
  # Condition of that leaf, rather than noted as a site of its own.
  # A new scope, eg a block's body or an if's arm, stops the
  # collecting, so a site in it is a site of its own. It relies on
  # its includer's condition_of, chain_condition, safe_chain?,
  # block_site? and extent_of.
  module ManifestFolding
    # The sites that fold into the leaf operand, as collected
    # finds them; none for a leaf that is wholly a site of its own,
    # as own_site? has it, visited as one, as the leaf's outcome is
    # its value.
    def leaf_sites(operand)
      unless own_site?(operand)
        return collected { operand.accept(self) }
      end

      scoped { operand.accept(self) }
      []
    end

    # True for a leaf that is wholly a site of its own: a block
    # method's call whose value follows from its path, or an && or
    # ||, eg a predicate, not ignored.
    def own_site?(node)
      valued?(node) || (operator?(node) && !ignored?(node))
    end

    # True for a block method's call that is a site, not ignored,
    # whose value follows from its path, eg any?, but not find.
    def valued?(node)
      node.type == :call_node && block_site?(node) &&
        VALUED.include?(node.name.to_s) && !ignored?(node)
    end

    # The one outcome each of a site's values gives a leaf.
    GIVEN = { [true] => :truthy, [false] => :falsy }.freeze

    # The one outcome the leaf node can have, as the site it wholly
    # is gives it on every one of its paths, eg :truthy for a
    # select, whose array is truthy; nil when its paths give both,
    # or node is no such site.
    def given_outcome(node)
      return nil unless own_site?(node)

      site = @sites.fetch(Site.at(@path, site_loc(node)))
      GIVEN[SitePaths.values(site).uniq]
    end

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
    # named contains: those sites, then range, the leaf's outcome,
    # fixed as :nonempty when nonempty. A leaf that is wholly one
    # block method's call whose value follows from its path never
    # comes here: it is a site of its own, as leaf_sites has it.
    def contained(inner, range, nonempty: false)
      return range if inner.empty?

      fixed = nonempty ? { range => :nonempty } : {}
      Condition.new(operator: CONTAINS, operands: [*inner, range],
                    extent: range, fixed:)
    end

    # True for a call, with no arguments or block, to a method
    # treated as nonempty, eg any?, whose receiver, parenthesised
    # or not, is one of inner, the sites found in it: its outcome
    # then follows from that site's path. It relies on its
    # includer's grouped.
    def nonempty_call?(node, inner)
      return false unless node.type == :call_node
      return false if node.arguments || node.block || !node.receiver

      receiver = extent_of(grouped(node.receiver))
      @nonempty.include?(node.name.to_s) &&
        inner.map(&:extent).include?(receiver)
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
