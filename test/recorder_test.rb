require_relative 'test_helper'
require 'path_coverage/recorder'

class RecorderTest < Id58TestBase
  test '8TuB10', %w(
  | recording an operand returns its value unchanged,
  | so the && it sits in still short-circuits
  | and still yields the same result
  ) do
    recorder = PathCoverage::Recorder.new
    kata = { 'id' => 'Kp9sA2' }
    assert_same kata, recorder.record('k.rb:2:2', 0, kata)
    assert_nil recorder.record('k.rb:2:2', 1, nil)
  end

  test '8TuB20', %w(
  | each operand's truthy and falsy outcomes are counted,
  | keyed by its site and index
  ) do
    recorder = PathCoverage::Recorder.new
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
    recorder = PathCoverage::Recorder.new
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
    recorder = PathCoverage::Recorder.new
    path = recorder.path('k.rb:1:0', 2)
    recorder.decide(path, 0, true)
    assert_equal({}, recorder.paths)
  end

  test '8TuB32', %w(
  | a decision taking the outcome whose arm always leaves
  | the method counts its path there, cut short, as the
  | call makes no more decisions
  ) do
    recorder = PathCoverage::Recorder.new
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

  test '8TuB50', %w(
  | each evaluation of a site, entered before its first leaf
  | and left after its last, counts its path: the outcome of
  | each leaf it reached, nil for one it never did; leaving
  | returns the site's value unchanged
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:2'
    # ok?(id) && new?(id), called twice
    trail = recorder.enter(site, 2)
    recorder.record(site, 0, true)
    recorder.record(site, 1, false)
    assert_same false, recorder.leave(trail, false)
    trail = recorder.enter(site, 2)
    recorder.record(site, 0, nil)
    assert_nil recorder.leave(trail, nil)
    expected = { site => { [true, false] => 1, [false, nil] => 1 } }
    assert_equal expected, recorder.site_paths
  end

  test '8TuB51', %w(
  | an evaluation of a site in another thread, while one is
  | under way, fills in a trail of its own, so neither
  | thread's path takes the other's outcomes
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:2'
    # ok?(id) && new?(id), in two threads at once
    entered = Queue.new
    resume = Queue.new
    trail = recorder.enter(site, 2)
    recorder.record(site, 0, true)
    other = Thread.new do
      mine = recorder.enter(site, 2)
      recorder.record(site, 0, false)
      entered.push(:entered)
      resume.pop
      recorder.leave(mine, false)
    end
    entered.pop
    recorder.record(site, 1, true)
    resume.push(:resume)
    other.join
    recorder.leave(trail, true)
    expected = { site => { [false, nil] => 1, [true, true] => 1 } }
    assert_equal expected, recorder.site_paths
  end

  test '8TuB52', %w(
  | an evaluation left while one of the same site it called
  | is still entered, eg after that one raised, counts no
  | path, since its later outcomes went to the other; so no
  | path is ever claimed as seen that was not, and the stack
  | is cleared down to it
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:2'
    # ok?(id) || retry?(id), whose retry? recursed and raised
    outer = recorder.enter(site, 2)
    recorder.record(site, 0, false)
    recorder.enter(site, 2)
    recorder.record(site, 1, true)
    assert_same true, recorder.leave(outer, true)
    assert_equal({}, recorder.site_paths)

    trail = recorder.enter(site, 2)
    recorder.record(site, 0, true)
    recorder.leave(trail, true)
    expected = { site => { [true, nil] => 1 } }
    assert_equal expected, recorder.site_paths
  end

  test '8TuB53', %w(
  | an evaluation left in a fiber other than the one that
  | entered it is not on that fiber's stack, so it counts
  | no path, and leaving it still returns
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:2'
    trail = Fiber.new do
      recorder.enter(site, 2).tap { recorder.record(site, 0, true) }
    end.resume
    assert_same :ok, recorder.leave(trail, :ok)
    assert_equal({}, recorder.site_paths)
  end
end
