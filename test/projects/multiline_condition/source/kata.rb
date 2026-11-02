module Kata
  def self.ok?(id)
    !id.empty? &&
      id.size < 9
  end

  def self.image?(name)
    name.start_with?('ghcr.io/') ||
      name.start_with?('docker.io/')
  end

  def self.size(id, max)
    size = id.size
    size -= 1 if id.start_with?('N')
    if size > max &&
       max.positive?
      size = max
    end
    size
  end
end
