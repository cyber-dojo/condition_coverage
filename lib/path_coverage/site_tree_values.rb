require_relative 'block_paths'
require_relative 'condition'

module PathCoverage
  # A condition's value in each column of a site's tree, as
  # SiteTree shows it on a nested condition's row: true, false, or
  # nil where the column never reached it.
  module SiteTreeValues
    # The value in each column of a condition named operator, from
    # the nodes of its operands: a ternary's, an if's or a write's
    # is its taken arm's body's, nil for a plain arm; a leaf with
    # sites inside it, the leaf's own; a block method's follows
    # from its path; a &. chain's is false where a receiver was
    # nil; a chain's is that of the last operand it reached.
    def self.value(operator, operands)
      return arms(operands) if [*CHOICES, *WRITES].include?(operator)
      return block(operator, operands) if BLOCK_PATHS.key?(operator)

      send(VALUES.fetch(operator, :chain), operands)
    end

    # The method giving the value of each other condition with one
    # of its own.
    VALUES = { SAFE => :safe, CONTAINS => :contains }.freeze

    # A chain's value in each column: the last operand it reached.
    def self.chain(operands)
      operands.map { |operand| operand[:cells] }
              .transpose.map { |column| column.compact.last }
    end

    # A leaf with sites inside it: the leaf's own value, its last
    # operand.
    def self.contains(operands)
      operands.last[:cells]
    end

    # A block method's value in each column, from its count of
    # items and its block's answer there; nil where it was not
    # reached.
    def self.block(operator, operands)
      receiver, body = operands
      receiver[:cells].zip(body[:cells]).map do |items, answer|
        items && BlockPaths.value(operator, items, answer)
      end
    end

    # A &. chain's value in each column: false where a receiver
    # was nil, as the chain then gives nil, else its last leaf's.
    def self.safe(operands)
      columns = operands.map { |operand| operand[:cells] }.transpose
      columns.map do |column|
        column.include?(PRESENCE[1]) ? false : column.last
      end
    end

    # A ternary's, an if's or a write's value in each column: its
    # taken arm's body's, nil for a plain arm.
    def self.arms(operands)
      _, *arms = operands
      bodies = arms.map { |arm| arm[:body]&.fetch(:cells) }
      arms.first[:cells].each_index.map do |column|
        taken = arms.index { |arm| arm[:cells][column] }
        taken && bodies[taken]&.fetch(column)
      end
    end
  end
end
