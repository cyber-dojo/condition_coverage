require_relative 'test_helper'
require 'open3'
require 'tmpdir'

class ProjectsTest < TidTest
  test '4WXv10', %w(
  | a project run with path coverage started prints,
  | as it exits, a line for each path through an && its run
  | never took
  ) do
    stdout, stderr, status = run_project('single_and')
    expected = [
      'source/kata.rb:3:23 path never taken: ' \
      "`ok?(id)` true, `id.start_with?('N')` false",
      'source/kata.rb:4:24 never reached'
    ].join("\n")
    assert_equal "#{expected}\n", stdout
    assert_equal '', stderr
    assert status.success?
  end

  test '4WXv20', %w(
  | Example: the nested_conditions project's kata.rb
  | It has || sites, chains, and nested and grouped conditions.
  | It has an any? folded into an ||, with a site inside its
  | block, a new scope.
  | It has an and whose operand is a command call.
  | All of them run unchanged when instrumented.
  | Their paths never taken are listed in source order.
  ) do
    stdout, stderr, status = run_project('nested_conditions')
    never = 'path never taken:'
    any = "source/kata.rb:17:4 #{never} `ids`"
    block = '`ok?(id) && id.size == 2`'
    expected = [
      "source/kata.rb:5:4 #{never} " \
      "`id.start_with?('N')` false, `id.size == 6` false",
      "source/kata.rb:9:4 #{never} " \
      '`ok?(id)` true, `id.size > 1` true, `id.size < 9` false',
      "source/kata.rb:9:4 #{never} " \
      '`ok?(id)` true, `id.size > 1` false',
      "source/kata.rb:13:4 #{never} `ok?(id)` true, " \
      "`id.start_with?('G')` false, `id.end_with?('G')` true",
      "source/kata.rb:13:4 #{never} `ok?(id)` true, " \
      "`id.start_with?('G')` false, `id.end_with?('G')` false",
      "#{any} 0 items, `ids.empty?` false",
      "#{any} 1 item, #{block} false, `ids.empty?` true",
      "#{any} 1 item, #{block} false, `ids.empty?` false",
      "#{any} 2+ items, #{block} true",
      "#{any} 2+ items, #{block} false, `ids.empty?` true",
      "#{any} 2+ items, #{block} false, `ids.empty?` false",
      "source/kata.rb:17:20 #{never} " \
      '`ok?(id)` true, `id.size == 2` false',
      "source/kata.rb:17:20 #{never} `ok?(id)` false",
      "source/kata.rb:21:4 #{never} " \
      "`ok?(id)` true, `id.include? 'N'` false"
    ].join("\n")
    assert_equal "#{expected}\n", stdout
    assert_equal '', stderr
    assert status.success?
  end

  test '4WXv30', %w(
  | Example: the multiline_condition project, run with
  | CONDITIONS off and then on
  | An instrumented file has the same relevant lines for
  | line coverage as it has uninstrumented.
  | So SimpleCov's line totals do not change.
  | That holds for a condition written over several lines.
  | It holds for a method whose paths are measured, with a
  | modifier if among its decisions.
  ) do
    off, = run_project('multiline_condition', 'CONDITIONS' => 'off')
    on, = run_project('multiline_condition', 'CONDITIONS' => 'on')
    assert_equal off, on
  end

  test '4WXv40', %w(
  | Example: total -= 10 if order.fetch(:total) > 100 && ...
  | The project measures methods too.
  | It prints its site gaps.
  | The modifier if's site is named at its keyword (5:16).
  | fee still runs unchanged when instrumented.
  ) do
    stdout, stderr, status = run_project('two_decisions')
    expected = [
      'source/shop.rb:5:16 path never taken: ' \
      '`order.fetch(:total) > 100` true, `order.fetch(:paid)` false'
    ].join("\n")
    assert_equal "#{expected}\n", stdout
    assert_equal '', stderr
    assert status.success?
  end

  private

  # Runs test/projects/name/run.rb in its own ruby process,
  # with env added to its environment, returning its stdout,
  # stderr and exit status.
  def run_project(name, env = {})
    run_rb = File.expand_path("projects/#{name}/run.rb", __dir__)
    lib = File.expand_path('../lib', __dir__)
    env = env.merge('COVERAGE_DIR' => Dir.mktmpdir(name))
    Open3.capture3(env, 'ruby', '-I', lib, run_rb)
  end
end
