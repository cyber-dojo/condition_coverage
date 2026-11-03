require 'fileutils'

# Self-coverage: path_coverage measuring its own lib/ and test/
# while its own tests run. The code measured and the tool
# measuring are the same code in one process, so the tool runs
# as a copy of lib/ renamed PathCoverageSelf, the calls it
# inserts included. The tests start and restart PathCoverage as
# they always do, untouched, as it is a different module. Loaded
# by bin/run_tests.sh on every run, before any of lib/ or
# test/, so every one of their files is instrumented as it
# loads, and before SimpleCov, so its report runs after
# SimpleCov's at exit and its summary prints below SimpleCov's.
module SelfCoverage
  COPY = '/tmp/path_coverage_self'.freeze

  # Copies lib/ to COPY with every PathCoverage renamed
  # PathCoverageSelf, and every inserted local renamed too, so
  # no name is shared with the code it measures.
  def self.copy
    FileUtils.rm_rf(COPY)
    FileUtils.cp_r('/gem/lib/.', COPY)
    Dir["#{COPY}/**/*.rb"].each do |file|
      text = File.read(file).gsub('PathCoverage', 'PathCoverageSelf')
      local = '__path_coverage_path'
      File.write(file, text.gsub(local, '__path_coverage_self_path'))
    end
  end

  # The copy's settings: lib/ and test/ covered, each a group
  # with a tab of its own, named code and test as SimpleCov's
  # groups are, reported into reports/paths at exit.
  SETTINGS = proc do
    root '/gem'
    cover 'lib/**/*.rb'
    cover 'test/**/*.rb'
    skip 'test/projects/**/*.rb'
    # SPIKE: the path grids of the HTML report, untested while
    # their design settles, as SimpleCov skips them too.
    skip 'lib/path_coverage/html_paths.rb'
    coverage_dir '/reports/paths'
    measure :decisions, :methods
    report :html
    group 'code', 'lib/**/*.rb'
    group 'test', 'test/**/*.rb'
  end

  # Starts the copy with SETTINGS.
  def self.start
    copy
    require "#{COPY}/path_coverage"
    PathCoverageSelf.start(&SETTINGS)
  end

  # Removes the copy's load hook, once every file of lib/ and
  # test/ is loaded and instrumented, so the tests install their
  # own as if it had never been there, with no warning that it
  # was redefined.
  def self.unhook
    hooks = RubyVM::InstructionSequence.singleton_class
    hooks.remove_method(:load_iseq)
  end
end

SelfCoverage.start
