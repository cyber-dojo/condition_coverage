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

  test '8TuB60', %w(
  | Example: case x when 1, 2 then :small when String then :text
  | else :other end
  | Each pattern, eg 1, is replaced by a stand-in.
  | Matching x against a stand-in matches x against its
  | pattern, once.
  | The stand-in records whether it matched.
  | The first pattern (1) enters the site.
  | A match, or the last pattern (String), leaves it.
  | So each evaluation's path is counted.
  | Eg 1 matches the first pattern, so no later one is tried.
  | The case still picks the same arm, eg :small for 2.
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:2'
    stand = lambda do |index, pattern|
      recorder.when_match(site, index, 3, pattern)
    end
    kind = lambda do |x|
      case x
      when stand.call(0, 1), stand.call(1, 2) then :small
      when stand.call(2, String) then :text
      else :other
      end
    end
    kinds = [1, 2, 'Kp', :k].map { |x| kind.call(x) }
    assert_equal %i[small small text other], kinds
    expected = {
      site => {
        [true, nil, nil] => 1,
        [false, true, nil] => 1, [false, false, true] => 1,
        [false, false, false] => 1
      }
    }
    assert_equal expected, recorder.site_paths
  end

  test '8TuB61', %w(
  | Example: ids.any? { |id| ok.include?(id) }
  | The call is entered before it runs.
  | It is left after it returns.
  | Each of the block's answers is noted on the way.
  | The path is how many ids the block was called with, and
  | its last answer, eg ['1 item', true].
  | The call's result and the block's answers are unchanged.
  | The receiver (ids) counts truthy when the block was called.
  | It counts falsy when the block was not called.
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:6'
    any = lambda do |ids, ok|
      trail = recorder.enter_items(site)
      found = ids.any? { |id| recorder.item(site, ok.include?(id)) }
      recorder.leave_items(trail, found)
    end
    founds = [[[], []], [[:a], [:a]], [%i[a b], []]].map do |ids, ok|
      any.call(ids, ok)
    end
    assert_equal [false, true, false], founds
    expected = {
      site => {
        ['0 items', nil] => 1, ['1 item', true] => 1,
        ['2+ items', false] => 1
      }
    }
    assert_equal expected, recorder.site_paths
    counts = {
      [site, 0] => { truthy: 2, falsy: 1 },
      [site, 1] => { truthy: 1, falsy: 2 }
    }
    assert_equal counts, recorder.counts
  end

  test '8TuB62', %w(
  | Example: any? entered in one fiber, its block run in another
  | The block's answer (:ok) is counted.
  | It is returned unchanged.
  | It is not noted on any path.
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:6'
    trail = recorder.enter_items(site)
    answer = Fiber.new { recorder.item(site, :ok) }.resume
    assert_same :ok, answer
    recorder.leave_items(trail, false)
    expected = { site => { ['0 items', nil] => 1 } }
    assert_equal expected, recorder.site_paths
    assert_equal({ truthy: 1, falsy: 0 }, recorder.counts[[site, 1]])
  end

  test '8TuB63', %w(
  | Example: ids.select { |id| id.odd? }
  | select calls its block with every item.
  | Each answer is noted.
  | The path is how many ids, and whether the answers were
  | all true, all false, or both.
  | Eg [1, 2] gives ['2+ items', 'both'].
  | The call's result and the block's answers are unchanged.
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:6'
    select = lambda do |ids|
      trail = recorder.enter_items(site)
      kept = ids.select { |id| recorder.answer(site, id.odd?) }
      recorder.leave_items(trail, kept)
    end
    kept = [[], [1], [1, 3], [1, 2]].map { |ids| select.call(ids) }
    assert_equal [[], [1], [1, 3], [1]], kept
    expected = {
      site => {
        ['0 items', nil] => 1, ['1 item', 'all true'] => 1,
        ['2+ items', 'all true'] => 1, ['2+ items', 'both'] => 1
      }
    }
    assert_equal expected, recorder.site_paths
    assert_equal({ truthy: 4, falsy: 1 }, recorder.counts[[site, 1]])
  end

  test '8TuB64', %w(
  | Example: select entered in one fiber, its block run in
  | another
  | The block's answer (nil) is counted.
  | It is returned unchanged.
  | It is not noted on any path.
  ) do
    recorder = PathCoverage::Recorder.new
    site = 'k.rb:2:6'
    trail = recorder.enter_items(site)
    answer = Fiber.new { recorder.answer(site, nil) }.resume
    assert_nil answer
    recorder.leave_items(trail, [])
    expected = { site => { ['0 items', nil] => 1 } }
    assert_equal expected, recorder.site_paths
    assert_equal({ truthy: 0, falsy: 1 }, recorder.counts[[site, 1]])
  end
end
