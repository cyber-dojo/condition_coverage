require 'prism'
require_relative 'condition'
require_relative 'site'

module ConditionCoverage
  # Finds every condition site in source without running it: each
  # outermost &&, ||, and or or, with the conditions nested in it.
  module Manifest
    # { site => Condition } for each site in source.
    def self.sites(source, path)
      collector = ConditionSites.new(path)
      Prism.parse(source).value.accept(collector)
      collector.sites
    end

    # The source and sites of the covered file at full_path.
    def self.parse(full_path, config)
      source = File.read(full_path)
      { source:, sites: sites(source, config.relative(full_path)) }
    end

    # True for a call to a named method with arguments and no
    # parentheses, eg `id.include? 'N'`, but not `id.size == 6`;
    # such a call is no bare argument, so a rewrite wrapping it
    # in another call must parenthesise it.
    def self.command?(node)
      node.type == :call_node && node.arguments &&
        node.opening_loc.nil? && node.name.match?(/\A[a-z_]/i)
    end

    # Collects each site and its Condition.
    class ConditionSites < Prism::Visitor
      # Starts with no sites found.
      def initialize(path)
        @path = path
        @sites = {}
        @notes = nil
        super()
      end

      # The sites found so far.
      attr_reader :sites

      OPERATOR_TYPES = %i[and_node or_node].freeze

      # Notes an && or and site.
      def visit_and_node(node)
        add_site(node)
      end

      # Notes an || or or site.
      def visit_or_node(node)
        add_site(node)
      end

      # Notes a ternary site, then any site in its then and else
      # arms, which decide something else; any other if is no
      # site itself.
      def visit_if_node(node)
        return super unless node.if_keyword_loc.nil?

        add_site(node)
        node.statements.accept(self)
        node.subsequent.accept(self)
      end

      # Notes node as a site. It claims its place first, so a
      # site found inside one of its leaves follows it, keeping
      # the sites in source order.
      def add_site(node)
        site = Site.of(@path, node)
        @sites[site] = nil
        outer = @notes
        @notes = { commands: [], fixed: {} }
        condition = condition_of(node)
        @sites[site] = condition.with(**@notes)
        @notes = outer
      end

      # node as a Condition, operands and all, named by its
      # operator as written; a ternary is named ?: and its one
      # operand is its predicate.
      def condition_of(node)
        ternary = node.type == :if_node
        Condition.new(
          operator: ternary ? '?:' : node.operator,
          operands:
            ternary ? [predicate_of(node)] : operands_of(node),
          extent: extent_of(node)
        )
      end

      # node's operands: a chain of the same operator flattened
      # into one list, the other operator nested as a Condition,
      # anything else a leaf's byte range.
      def operands_of(node)
        [node.left, node.right].flat_map do |written|
          operand = grouped(written)
          next operands_of(operand) if operand.type == node.type
          next [condition_of(operand)] if operator?(operand)

          [leaf(operand)]
        end
      end

      # The byte range of node as written.
      def extent_of(node)
        loc = node.location
        loc.start_offset...loc.end_offset
      end

      # A ternary's predicate as its operand: an && or || nested
      # as a Condition, anything else a leaf.
      def predicate_of(node)
        predicate = node.predicate
        return condition_of(predicate) if operator?(predicate)

        leaf(predicate)
      end

      # True for an &&, ||, and or or node.
      def operator?(node)
        OPERATOR_TYPES.include?(node.type)
      end

      # The byte range of a leaf operand, once any site inside
      # it is noted too, and the range noted among its site's
      # commands and fixed leaves where it is one.
      def leaf(operand)
        operand.accept(self)
        loc = operand.location
        range = loc.start_offset...loc.end_offset
        @notes[:commands] << range if command?(operand)
        outcome = fixed_outcome(operand)
        @notes[:fixed][range] = outcome if outcome
        range
      end

      # Literals and lambdas, whose value is truthy by their form;
      # a constant is not among them, as it can hold nil or false.
      TRUTHY_TYPES = %i[
        string_node integer_node symbol_node array_node hash_node
        true_node lambda_node
      ].freeze
      FALSY_TYPES = %i[nil_node false_node].freeze

      # Ruby raises TypeError on assigning nil or false to these.
      TRUTHY_GLOBALS = %i[$stdout $stderr].freeze

      # The one outcome a leaf can have, eg :truthy for `Clock.new`
      # or a literal, :falsy for `nil`; nil for a leaf that can
      # have either.
      def fixed_outcome(node)
        return :falsy if FALSY_TYPES.include?(node.type)

        :truthy if truthy_only?(node)
      end

      # True for a leaf that can never be falsy.
      def truthy_only?(node)
        TRUTHY_TYPES.include?(node.type) || new_call?(node) ||
          truthy_global?(node)
      end

      # True for a call to new, eg `Clock.new`.
      def new_call?(node)
        node.type == :call_node && node.name == :new
      end

      # True for $stdout or $stderr, which can never be falsy.
      def truthy_global?(node)
        node.type == :global_variable_read_node &&
          TRUTHY_GLOBALS.include?(node.name)
      end

      # True for a command call, as Manifest.command? says.
      def command?(node)
        Manifest.command?(node)
      end

      # The one statement inside a parenthesised operand, or the
      # operand itself.
      def grouped(operand)
        return operand unless operand.type == :parentheses_node

        statements = operand.body&.body || []
        statements.size == 1 ? statements.first : operand
      end
    end
  end
end
