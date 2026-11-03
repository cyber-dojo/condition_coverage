require_relative 'condition'

module PathCoverage
  # The part of the rewriter that instruments ||= and &&=
  # writes, its inserts spliced in by Rewriter.apply.
  module RewriterWrites
    # The inserts for a ||= or &&= write at site: the whole of it
    # in a leave_write call that enters it first, and its right
    # side in a written call, which notes the target's outcome
    # when it runs; leave_write notes the other when it does not.
    # The target itself is never wrapped, so never read again.
    # Eg x ||= v becomes, in effect, leave_write(enter(site, 1),
    # true, x ||= written(site, false, v)).
    def self.inserts(site, condition)
      _target, arm = condition.operands
      ran = THEN_ON[condition.operator]
      enter = "PathCoverage.enter(#{site.inspect}, 1)"
      leave = "PathCoverage.leave_write(#{enter}, #{!ran}, "
      written = "PathCoverage.written(#{site.inspect}, #{ran}, "
      command = condition.commands.include?(arm.extent)
      Rewriter.wrap(leave, condition.extent, false, 1) +
        Rewriter.wrap(written, arm.extent, command, 0)
    end
  end
end
