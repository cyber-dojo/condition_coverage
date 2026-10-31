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
