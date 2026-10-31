require 'prism'
require_relative 'site'

module ConditionCoverage
  # Finds every && site in source without running it.
  module Manifest
    # { site => operand count } for each && in source.
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

      # Notes an && site and its two operands.
      def visit_and_node(node)
        @sites[Site.of(@path, node)] = 2
      end
    end
  end
end
