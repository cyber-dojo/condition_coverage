require 'prism'

module ConditionCoverage
  # Instruments source text so that each condition
  # records its outcome when the code runs.
  module Rewriter
    # Returns source with each && operand wrapped in a
    # record call. Only text is inserted, never a
    # newline, so backtrace line numbers still match.
    def self.rewrite(source, path)
      inserts = []
      collector = AndCollector.new(path, inserts)
      Prism.parse(source).value.accept(collector)
      apply(source.dup, inserts)
    end

    # Splices each [offset, text] insert into source,
    # last offset first so earlier offsets stay valid.
    def self.apply(source, inserts)
      sorted = inserts.sort_by { |offset, _| -offset }
      sorted.each do |offset, text|
        source.bytesplice(offset, 0, text)
      end
      source
    end

    # Collects the inserts that wrap each && operand.
    class AndCollector < Prism::Visitor
      # Appends [byte offset, text] pairs to inserts.
      def initialize(path, inserts)
        @path = path
        @inserts = inserts
        super()
      end

      # Wraps both operands of an &&.
      def visit_and_node(node)
        site = site_of(node)
        wrap(site, 0, node.left)
        wrap(site, 1, node.right)
      end

      private

      # Returns "path:line:column" of the && itself.
      def site_of(node)
        loc = node.location
        "#{@path}:#{loc.start_line}:#{loc.start_column}"
      end

      # Inserts the record call around one operand.
      def wrap(site, index, operand)
        loc = operand.location
        call = "ConditionCoverage.record(#{site.inspect}, "
        @inserts << [loc.start_offset, "#{call}#{index}, "]
        @inserts << [loc.end_offset, ')']
      end
    end
  end
end
