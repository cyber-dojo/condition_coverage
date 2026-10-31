require_relative 'test_helper'
require 'open3'
require 'tmpdir'

class ProjectsTest < Id58TestBase
  test '4WXv10', %w(
  | a project run with condition coverage started prints,
  | as it exits, a line for each && outcome its run missed
  ) do
    stdout, stderr, status = run_project('single_and')
    expected = [
      'source/kata.rb:3:23 operand 1 never false',
      'source/kata.rb:4:24 never reached'
    ].join("\n")
    assert_equal "#{expected}\n", stdout
    assert_equal '', stderr
    assert status.success?
  end

  test '4WXv20', %w(
  | || sites, chains, nested and grouped conditions, a site
  | inside a block, and an and whose operand is a command call
  | all run unchanged when instrumented, and their gaps are
  | listed in source order, each leaf indexed left to right
  ) do
    stdout, stderr, status = run_project('nested_conditions')
    expected = [
      'source/kata.rb:5:4 operand 1 never false',
      'source/kata.rb:9:4 operand 1 never false',
      'source/kata.rb:9:4 operand 2 never false',
      'source/kata.rb:13:4 operand 1 never false',
      'source/kata.rb:13:4 operand 2 never evaluated',
      'source/kata.rb:17:4 operand 1 never false',
      'source/kata.rb:17:20 operand 0 never false',
      'source/kata.rb:17:20 operand 1 never false',
      'source/kata.rb:21:4 operand 1 never false'
    ].join("\n")
    assert_equal "#{expected}\n", stdout
    assert_equal '', stderr
    assert status.success?
  end

  private

  # Runs test/projects/name/run.rb in its own ruby process,
  # returning its stdout, stderr and exit status.
  def run_project(name)
    run_rb = File.expand_path("projects/#{name}/run.rb", __dir__)
    lib = File.expand_path('../lib', __dir__)
    env = { 'COVERAGE_DIR' => Dir.mktmpdir(name) }
    Open3.capture3(env, 'ruby', '-I', lib, run_rb)
  end
end
