require_relative 'recorder'
require_relative 'rewriter'

# Condition coverage for Ruby. This file is the kernel: it loads
# before any covered file and is never itself instrumented, since
# an instrumented recorder would record itself.
module ConditionCoverage
  @recorder = Recorder.new

  # The one recorder that every instrumented operand reports to.
  def self.recorder
    @recorder
  end

  # The call rewritten code makes around each operand; returns
  # value unchanged.
  def self.record(site, index, value)
    @recorder.record(site, index, value)
  end

  # Instruments every file later required from under cover,
  # rewriting its source in memory as it loads.
  def self.start(cover:)
    iseq = RubyVM::InstructionSequence
    iseq.singleton_class.define_method(:load_iseq) do |path|
      ConditionCoverage.instrumented(path, cover)
    end
  end

  # The compiled, rewritten code of path, or nil for a path
  # outside cover, which Ruby then loads as normal.
  def self.instrumented(path, cover)
    return unless path.start_with?(cover)

    source = Rewriter.rewrite(File.read(path), path)
    RubyVM::InstructionSequence.compile(source, path, path)
  end
end
