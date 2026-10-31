require_relative 'test_helper'
require 'condition_coverage/recorder'

class RecorderTest < Id58TestBase
  test '8TuB10', %w(
  | recording an operand returns its value unchanged,
  | so the && it sits in still short-circuits
  | and still yields the same result
  ) do
    recorder = ConditionCoverage::Recorder.new
    kata = { 'id' => 'Kp9sA2' }
    assert_same kata, recorder.record('k.rb:2:2', 0, kata)
    assert_nil recorder.record('k.rb:2:2', 1, nil)
  end

  test '8TuB20', %w(
  | each operand's truthy and falsy outcomes are counted,
  | keyed by its site and index
  ) do
    recorder = ConditionCoverage::Recorder.new
    site = 'k.rb:2:2'
    # ok?(id) && new?(id), called three times
    recorder.record(site, 0, true)
    recorder.record(site, 1, true)
    recorder.record(site, 0, true)
    recorder.record(site, 1, false)
    recorder.record(site, 0, nil) # so new?(id) never runs
    expected = {
      [site, 0] => { truthy: 2, falsy: 1 },
      [site, 1] => { truthy: 1, falsy: 1 }
    }
    assert_equal expected, recorder.counts
  end
end
