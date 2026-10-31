# Rules about old katas. demo/run.rb never loads this file,
# so its condition is reported as never reached.
module Archive
  # True for a kata old enough to archive, unless pinned.
  def self.old?(kata) = kata.age > 365 && !kata.pinned
end
