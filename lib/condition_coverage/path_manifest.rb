require 'prism'
require_relative 'manifest'
require_relative 'site'

module ConditionCoverage
  # One if a method's path passes: its line, the byte range of
  # its predicate, and whether that predicate is a command call.
  # exits is the outcome whose arm always leaves the method,
  # ending the path there, or nil when neither arm does.
  Decision = Data.define(:line, :range, :command, :exits) do
    # A decision with no arm that leaves by default.
    def initialize(line:, range:, command:, exits: nil)
      super
    end
  end

  # A method whose calls each take one path through its
  # decisions, in source order. entry is the byte offset of its
  # first decision's statement, where each call's path starts.
  PathMethod = Data.define(:name, :entry, :decisions)

  # Finds, without running it, the decisions of each method in
  # source whose paths are to be counted.
  module PathManifest
    # { def site => PathMethod } for each def in source.
    def self.methods(source, path)
      collector = PathMethods.new(path)
      Prism.parse(source).value.accept(collector)
      collector.methods
    end

    # Collects each def and the ifs at the top level of its body.
    class PathMethods < Prism::Visitor
      # Starts with no methods found.
      def initialize(path)
        @path = path
        @methods = {}
        super()
      end

      # The methods found so far.
      attr_reader :methods

      # Notes node's top-level ifs as its decisions, when it has
      # at least two (with fewer its paths are its branches),
      # then any def inside it, each a method of its own.
      def visit_def_node(node)
        ifs = statements_of(node.body).select do |statement|
          statement.type == :if_node
        end
        note(node, ifs) if ifs.size >= 2
        super
      end

      # Notes node as a method whose decisions are ifs.
      def note(node, ifs)
        @methods[Site.of(@path, node)] = PathMethod.new(
          name: node.name,
          entry: ifs.first.location.start_offset,
          decisions: ifs.map { |statement| decision(statement) }
        )
      end

      # The top-level statements of a def's body: those before
      # any rescue, and none for an empty or endless def.
      def statements_of(body)
        body = body.statements if body&.type == :begin_node
        body&.type == :statements_node ? body.body : []
      end

      # The Decision of an if statement.
      def decision(statement)
        predicate = statement.predicate
        loc = predicate.location
        Decision.new(
          line: loc.start_line,
          range: loc.start_offset...loc.end_offset,
          command: Manifest.command?(predicate) || false,
          exits: exits(statement)
        )
      end

      LEAVING_CALLS = %i[fail raise].freeze

      # The outcome of an if statement whose arm always leaves
      # the method: true for its then arm, false for its else
      # arm, nil for neither.
      def exits(statement)
        return true if leaves?(statement.statements)

        otherwise = statement.subsequent
        false if otherwise&.type == :else_node &&
                 leaves?(otherwise.statements)
      end

      # True when the last of statements is a return, or a
      # fail or raise of the method's own; false for an empty
      # arm, which has no statements.
      def leaves?(statements)
        return false if statements.nil?

        last = statements.body.last
        return true if last.type == :return_node

        last.type == :call_node && last.receiver.nil? &&
          LEAVING_CALLS.include?(last.name)
      end
    end
  end
end
