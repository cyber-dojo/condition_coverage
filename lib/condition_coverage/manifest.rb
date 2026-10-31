require 'prism'
require_relative 'site'

module ConditionCoverage
  # Finds every && site in source without running it.
  module Manifest
    # { site => [byte range of each operand] } for each && in
    # source.
    def self.sites(source, path)
      collector = AndSites.new(path)
      Prism.parse(source).value.accept(collector)
      collector.sites
    end

    # Collects the site and operand count of each &&.
    class AndSites < Prism::Visitor
      # Starts with no sites found.
      def initialize(path)
        @path = path
        @sites = {}
        super()
      end

      # The sites found so far.
      attr_reader :sites

      # Notes an && site and the byte ranges of its operands.
      def visit_and_node(node)
        operands = [node.left, node.right].map do |operand|
          loc = operand.location
          loc.start_offset...loc.end_offset
        end
        @sites[Site.of(@path, node)] = operands
      end
    end
  end
end
