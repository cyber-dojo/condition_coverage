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

  test '8TuB30', %w(
  | each call's path, the outcomes of its method's decisions
  | in order, is counted when its last decision is made,
  | keyed by the method's site; deciding returns the
  | predicate's value unchanged
  ) do
    recorder = ConditionCoverage::Recorder.new
    site = 'k.rb:1:0'
    # fee(user, order), called three times
    calls = [[:gold, false], [false, :big], [:gold, false]]
    calls.each do |member, big|
      path = recorder.path(site, 2)
      assert_same member, recorder.decide(path, 0, member)
      assert_same big, recorder.decide(path, 1, big)
    end
    expected = { site => { [true, false] => 2, [false, true] => 1 } }
    assert_equal expected, recorder.paths
  end

  test '8TuB31', %w(
  | a call that leaves before its last decision, by return
  | or raise, counts no path, so no path is ever claimed
  | as seen that was not taken all the way through
  ) do
    recorder = ConditionCoverage::Recorder.new
    path = recorder.path('k.rb:1:0', 2)
    recorder.decide(path, 0, true)
    assert_equal({}, recorder.paths)
  end

  test '8TuB32', %w(
  | a decision taking the outcome whose arm always leaves
  | the method counts its path there, cut short, as the
  | call makes no more decisions
  ) do
    recorder = ConditionCoverage::Recorder.new
    site = 'k.rb:1:0'
    # fork(id), whose first decision fails when id has no group
    path = recorder.path(site, 2)
    recorder.decide(path, 0, :no_group, true)
    path = recorder.path(site, 2)
    recorder.decide(path, 0, false, true)
    recorder.decide(path, 1, :odd)
    expected = { site => { [true] => 1, [false, true] => 1 } }
    assert_equal expected, recorder.paths
  end

  test '8TuB40', %w(
  | each site's own outcome, eg the predicate deciding a
  | ternary's arm, is counted truthy or falsy, keyed by its
  | site, and returned unchanged
  ) do
    recorder = ConditionCoverage::Recorder.new
    site = 'k.rb:2:2'
    # ok?(id) ? :ok : :no, called three times
    assert_same :gold, recorder.outcome(site, :gold)
    assert_same :gold, recorder.outcome(site, :gold)
    assert_nil recorder.outcome(site, nil)
    expected = { site => { truthy: 2, falsy: 1 } }
    assert_equal expected, recorder.outcomes
  end
end
