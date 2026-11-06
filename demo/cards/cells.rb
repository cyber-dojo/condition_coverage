# The README's card examples: one method for each kind of
# cell, each called by run.rb so its card shows that cell.
module Cells
  # T and F: whether each leaf was true or false.
  def self.long?(name) = name.size > 2 && name.ascii_only?

  # A blank: a leaf a path cannot reach.
  def self.called(nick, name) = nick || name

  # 0, 1 and *: how many items a block was called with.
  def self.any_odd?(ids) = ids.any? { |id| id.odd? }

  # T, F and TF: every answer of a block called with every item.
  def self.odds(ids) = ids.select { |id| id.odd? }

  # nil and not nil: whether a &. receiver was nil.
  def self.name_of(user) = user&.name

  # The tick: the arm each path took.
  def self.label(paid)
    paid ? 'paid' : 'due'
  end
end
