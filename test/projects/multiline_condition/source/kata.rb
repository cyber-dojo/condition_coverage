module Kata
  def self.ok?(id)
    !id.empty? &&
      id.size < 9
  end

  def self.image?(name)
    name.start_with?('ghcr.io/') ||
      name.start_with?('docker.io/')
  end
end
