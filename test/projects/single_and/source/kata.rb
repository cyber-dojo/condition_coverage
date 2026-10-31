module Kata
  def self.ok?(id) = !id.empty?
  def self.kata?(id) = ok?(id) && id.start_with?('N')
  def self.group?(id) = ok?(id) && id.size == 6
end
