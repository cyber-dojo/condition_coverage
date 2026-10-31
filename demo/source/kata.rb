# Rules about one practice session.
module Kata
  # True for a six-character id.
  def self.id?(id) = id.is_a?(String) && id.size == 6

  # True for a kata started and not yet finished.
  def self.runnable?(kata)
    kata.started &&
      !kata.finished
  end

  # [both ids valid, the two ids different].
  def self.pair_checks(one, other)
    [id?(one) && id?(other), one != other && other != '']
  end
end
