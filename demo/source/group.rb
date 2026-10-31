# Rules about a group of katas.
module Group
  # True when the group has no room for another kata.
  def self.full?(group) = group.size >= 64 && group.open
end
