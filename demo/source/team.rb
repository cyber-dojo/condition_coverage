# Rules about who may join and edit a kata.
module Team
  # True for a name that is short, plain and not yet taken.
  def self.name?(name, taken)
    name.size < 9 && name.match?(/\A[a-z]+\z/) &&
      !taken.include?(name)
  end

  # True for a member who may edit: an owner, or an editor
  # whose invite is still open.
  def self.can_edit?(member)
    member.owner || (member.editor && member.invite_open)
  end

  # True when an active owner leads the team, or it is empty.
  def self.led?(members)
    members.any? { |m| m.owner && m.active } || members.empty?
  end
end
