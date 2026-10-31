require_relative 'test_helper'
require 'condition_coverage/kernel'
require 'tmpdir'

class KernelTest < Id58TestBase
  test '6rTS10', %w(
  | ConditionCoverage.record, the call rewritten code makes,
  | returns the operand's value and counts it
  | in the one shared recorder
  ) do
    site = 'kernel_test.rb:6rTS10:0' # used by no other test
    kata = { 'id' => 'Kp9sA2' }
    assert_same kata, ConditionCoverage.record(site, 0, kata)
    expected = { truthy: 1, falsy: 0 }
    actual = ConditionCoverage.recorder.counts[[site, 0]]
    assert_equal expected, actual
  end

  test '6rTS20', %w(
  | once started, a file required from a covered dir
  | has its && operands recorded when they run
  ) do
    dir = Dir.mktmpdir('6rTS20')
    path = "#{dir}/kata.rb"
    File.write(path, <<~RUBY)
      module Kata6rTS20
        def self.ok?(id) = !id.empty?
        def self.kata?(id) = ok?(id) && id.start_with?('N')
      end
    RUBY
    ConditionCoverage.start(cover: dir)
    require path
    Kata6rTS20.kata?('N1')
    site = "#{path}:3:23"
    expected = {
      [site, 0] => { truthy: 1, falsy: 0 },
      [site, 1] => { truthy: 1, falsy: 0 }
    }
    counts = ConditionCoverage.recorder.counts
    actual = counts.select { |(s, _), _| s == site }
    assert_equal expected, actual
  end

  test '6rTS30', %w(
  | a file outside the covered dir is left for Ruby
  | to load as normal, uninstrumented
  ) do
    covered = Dir.mktmpdir('6rTS30-covered')
    other = Dir.mktmpdir('6rTS30-other')
    path = "#{other}/kata.rb"
    File.write(path, "def kata?(id) = ok?(id) && new?(id)\n")
    assert_nil ConditionCoverage.instrumented(path, covered)
  end
end
