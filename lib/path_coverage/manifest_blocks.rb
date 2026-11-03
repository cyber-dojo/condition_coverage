require_relative 'condition'

module PathCoverage
  # The part of the manifest's visitor that builds the site of a
  # call to a block method, one that calls its block an item at
  # a time, until it decides, eg any?, or for every item, eg
  # select: its leaves are its receiver, whose items the block
  # is called with, and its block's one expression, whose
  # answers decide. It relies on its includer's extent_of and
  # @notes.
  module ManifestBlocks
    # True for a call whose block's every call can be seen: to a
    # block method, on a receiver, with no arguments, which can
    # make it ignore its block, not by &., which skips it for
    # nil, and with a block of one expression.
    def block_site?(node)
      BLOCK_PATHS.key?(node.name.to_s) && !node.receiver.nil? &&
        node.arguments.nil? && !node.safe_navigation? &&
        !block_expression(node.block).nil?
    end

    # The one expression of block, nil for no block, a block
    # passed as an argument, or one of other than one expression.
    def block_expression(block)
      return nil unless block&.type == :block_node

      statements = block.body
      return nil unless statements&.type == :statements_node

      statements.body.size == 1 ? statements.body.first : nil
    end

    # A block method's call as a Condition, named by its method,
    # its extent the whole call. Its block's expression is noted
    # among the commands when it is no bare argument.
    def block_condition(node)
      node.receiver.accept(self)
      body = block_expression(node.block)
      body.accept(self)
      @notes[:commands] << extent_of(body) if bare_less?(body)
      Condition.new(
        operator: node.name.to_s,
        operands: [extent_of(node.receiver), extent_of(body)],
        extent: extent_of(node)
      )
    end

    # True for an expression that is no bare argument: a command
    # call, or an and or an or.
    def bare_less?(node)
      return true if Manifest.command?(node)

      %i[and_node or_node].include?(node.type) &&
        %w[and or].include?(node.operator)
    end
  end
end
