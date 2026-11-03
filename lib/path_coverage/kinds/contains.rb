require_relative 'base'
require_relative 'block'

module PathCoverage
  module Kinds
    # A leaf with sites inside it, eg ids.select { |i| i.odd? }.any?
    # as an operand of an &&: its operands are those sites'
    # Conditions, which run as it does, then the leaf's own byte
    # range, whose outcome is its value.
    module Contains
      extend Base

      OPERATORS = [CONTAINS].freeze

      # The ways node can be evaluated: each way of every one of
      # the sites inside it, then each way of the leaf itself, its
      # value the whole's.
      def self.ways(node, fixed)
        inner = node.operands[0...-1]
        before = inner.reduce([{}]) do |ways, site|
          ways.product(SitePaths.walk(site, fixed))
              .map { |outcomes, (more, _)| outcomes.merge(more) }
        end
        before.flat_map do |outcomes|
          leaf_ways(node, outcomes, fixed).map do |more, value|
            [outcomes.merge(more), value]
          end
        end
      end

      # The ways the leaf of node can be evaluated after the sites
      # inside it took outcomes: true or false, or, for a call
      # treated as nonempty, eg any?, only whether its receiver
      # has items on that path, when its kind can tell. Such a
      # call has no arguments, so its receiver is the largest of
      # those sites, any other lying within it.
      def self.leaf_ways(node, outcomes, fixed)
        *inner, range = node.operands
        if node.fixed[range] == :nonempty
          receiver = inner.max_by { |site| site.extent.size }
          has = Block.items?(receiver, outcomes)
          return [[{ range => has }, has]] unless has.nil?
        end
        SitePaths.leaf(range, fixed)
      end

      # Its value in each column: the leaf's own, its last operand.
      def self.value(_operator, operands)
        operands.last[:cells]
      end

      # Stands in for a site inside a leaf's text, eg ….any?.
      ELLIPSIS = [0x2026].pack('U').freeze

      # nodes with the leaf's own node texted with only what it
      # adds to the sites inside it, each site's text an ellipsis,
      # eg ….any? for ids.select { |id| id.odd? }.any?, as those
      # sites have rows of their own.
      def self.texted(source, condition, nodes)
        *inner, range = condition.operands
        extents = inner.map(&:extent).sort_by(&:begin).reverse
        whole = source.byteslice(range)
        text = extents.reduce(whole) do |rest, extent|
          elide(rest, extent.begin - range.begin, extent.size)
        end
        [*nodes[0...-1], nodes.last.merge(text:)]
      end

      # The sites inside it, then the leaf, as siblings, so each
      # site's rows are drawn once, eg select then ….any?.
      def self.unfold(node)
        node[:operands]
      end

      # text with the size bytes from byte from an ellipsis.
      def self.elide(text, from, size)
        after = text.byteslice((from + size)..)
        text.byteslice(0, from) + ELLIPSIS + after
      end
    end
  end
end
