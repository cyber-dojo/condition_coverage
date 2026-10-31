module Kata
  def self.ok?(id) = !id.empty?

  def self.either?(id)
    id.start_with?('N') || id.size == 6
  end

  def self.kata?(id)
    ok?(id) && id.size > 1 && id.size < 9
  end

  def self.group?(id)
    ok?(id) && (id.start_with?('G') || id.end_with?('G'))
  end

  def self.listed?(ids)
    ids.any? { |id| ok?(id) && id.size == 2 } || ids.empty?
  end

  def self.both?(id)
    ok?(id) and id.include? 'N'
  end
end
