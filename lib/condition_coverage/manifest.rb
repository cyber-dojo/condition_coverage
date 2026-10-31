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

    # Collects each site and its Condition.
    class ConditionSites < Prism::Visitor
      # Starts with no sites found.
      def initialize(path)
        @path = path
        @sites = {}
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

      # Notes node as a site. It claims its place first, so a
      # site found inside one of its leaves follows it, keeping
      # the sites in source order.
      def add_site(node)
        site = Site.of(@path, node)
        @sites[site] = nil
        @sites[site] = condition_of(node)
      end

      # node as a Condition, operands and all, named by its
      # operator as written.
      def condition_of(node)
        operator = node.operator
        Condition.new(operator:, operands: operands_of(node))
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

      # True for an &&, ||, and or or node.
      def operator?(node)
        OPERATOR_TYPES.include?(node.type)
      end

      # The byte range of a leaf operand, once any site inside
      # it is noted too.
      def leaf(operand)
        operand.accept(self)
        loc = operand.location
        loc.start_offset...loc.end_offset
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
