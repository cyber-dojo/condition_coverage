require_relative 'condition'

module PathCoverage
  # The paths and values of a block method's call, eg
  # ids.any? { |id| id.odd? }, fixed by its shape: its receiver's
  # count of items with its block's answers.
  module BlockPaths
    # The ways node, a block method's call nested in a site, can be
    # evaluated, as SitePaths.walk gives them, its value following
    # from each.
    def self.ways(node)
      receiver, body = node.operands
      BLOCK_PATHS[node.operator].map do |items, answer|
        value = value(node.operator, items, answer)
        [{ receiver => items, body => answer }, value]
      end
    end

    # A value that holds whatever the path, eg select's array.
    ALWAYS = ->(*) { true }

    # A block method's value from whether its block was called
    # with no items, and its block's last answer.
    VALUES = {
      'any?' => ->(none, answer) { !none && answer },
      'find_index' => ->(none, answer) { !none && answer },
      'all?' => ->(none, answer) { none || answer },
      'none?' => ->(none, answer) { none || !answer },
      'take_while' => ALWAYS,
      **EVERY_ITEM.to_h { |name| [name, ALWAYS] }
    }.freeze

    # A block method's value on a path: its count of items and its
    # block's answer, eg false for any? called with 0 items, and
    # always truthy for select, which gives an array; nil for find
    # and detect, whose value no path can tell.
    def self.value(operator, items, answer)
      VALUES[operator]&.call(items == ITEMS[0], answer)
    end
  end
end
