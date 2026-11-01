require_relative 'test_helper'
require 'condition_coverage/kernel'
require 'json'
require 'tmpdir'

class KernelTest < Id58TestBase
  # Its tests swap the configuration of the one global load
  # hook, and capture $stdout.
  serial!

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
  | once started with a root and a cover glob,
  | a file matching the glob has its && operands recorded
  | when they run, at sites named relative to the root
  ) do
    dir = Dir.mktmpdir('6rTS20')
    File.write("#{dir}/kata.rb", <<~RUBY)
      module Kata6rTS20
        def self.ok?(id) = !id.empty?
        def self.kata?(id) = ok?(id) && id.start_with?('N')
      end
    RUBY
    on_exit = ->(&_report) {} # this test checks the recording only
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
    end
    require "#{dir}/kata.rb"
    Kata6rTS20.kata?('N1')
    site = 'kata.rb:3:23'
    expected = {
      [site, 0] => { truthy: 1, falsy: 0 },
      [site, 1] => { truthy: 1, falsy: 0 }
    }
    counts = ConditionCoverage.recorder.counts
    actual = counts.select { |(s, _), _| s == site }
    assert_equal expected, actual
  end

  test '6rTS30', %w(
  | a file outside the root is left for Ruby
  | to load as normal, uninstrumented
  ) do
    covered = Dir.mktmpdir('6rTS30-covered')
    other = Dir.mktmpdir('6rTS30-other')
    path = "#{other}/kata.rb"
    File.write(path, "def kata?(id) = ok?(id) && new?(id)\n")
    config = ConditionCoverage::Configuration.new do
      root covered
      cover '*.rb'
    end
    assert_nil ConditionCoverage.instrumented(path, config)
  end

  test '6rTS40', %w(
  | the report made as the process exits prints the gaps
  | and writes every operand count as JSON to coverage_dir
  ) do
    dir = Dir.mktmpdir('6rTS40')
    File.write("#{dir}/group.rb", <<~RUBY)
      module Group6rTS40
        def self.ok?(id) = !id.empty?
        def self.group?(id) = ok?(id) && id.size == 6
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/group.rb"
    Group6rTS40.group?('Kp9sA2')
    expected = [
      'group.rb:3:24 operand 0 never false',
      'group.rb:3:24 operand 1 never false'
    ].join("\n")
    assert_output("#{expected}\n") { report.call }

    json = JSON.parse(File.read("#{dir}/condition_coverage.json"))
    expected = {
      'group.rb:3:24' => [
        { 'truthy' => 1, 'falsy' => 0 },
        { 'truthy' => 1, 'falsy' => 0 }
      ]
    }
    assert_equal expected, json['sites']
  end

  test '6rTS45', %w(
  | a file loaded during the run is not read again for the
  | exit report: the sites parsed as it loaded are reused,
  | so each covered file is read and parsed at most once
  ) do
    dir = Dir.mktmpdir('6rTS45')
    path = "#{dir}/team.rb"
    File.write(path, <<~RUBY)
      module Team6rTS45
        def self.ok?(id) = !id.empty?
        def self.team?(id) = ok?(id) && id.size == 6
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require path
    Team6rTS45.team?('Kp9sA2')
    # A re-read of the file now would find no &&.
    File.write(path, "module Team6rTS45; end\n")
    expected = [
      'team.rb:3:23 operand 0 never false',
      'team.rb:3:23 operand 1 never false'
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
  end

  test '6rTS47', %w(
  | a covered file the run never loads is parsed for the
  | exit report, so each of its && sites is reported
  | as never reached
  ) do
    dir = Dir.mktmpdir('6rTS47')
    File.write("#{dir}/squad.rb", <<~RUBY)
      module Squad6rTS47
        def self.ok?(id) = !id.empty?
        def self.squad?(id) = ok?(id) && id.size == 6
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    assert_output("squad.rb:3:24 never reached\n") { report.call }
  end

  test '6rTS48', %w(
  | with report :html the exit report writes the index page
  | and a page per covered file into coverage_dir, and
  | prints no gaps, since :gaps was not chosen
  ) do
    dir = Dir.mktmpdir('6rTS48')
    File.write("#{dir}/crew.rb", <<~RUBY)
      module Crew6rTS48
        def self.ok?(id) = !id.empty?
        def self.crew?(id) = ok?(id) && id.size == 6
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :html
    end
    require "#{dir}/crew.rb"
    Crew6rTS48.crew?('Kp9sA2')

    assert_output('', '') { exit_report.call }

    assert File.file?("#{dir}/index.html")
    assert File.file?("#{dir}/files/crew.rb.html")
  end

  test '6rTS49', %w(
  | a coverage_dir that does not exist yet is created,
  | parents and all, before the exit report writes into it
  ) do
    dir = Dir.mktmpdir('6rTS49')
    File.write("#{dir}/pair.rb", <<~RUBY)
      module Pair6rTS49
        def self.ok?(id) = !id.empty?
        def self.pair?(id) = ok?(id) && id.size == 6
      end
    RUBY
    out = "#{dir}/reports/condition"
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir out
      report :html
    end
    exit_report.call

    assert File.file?("#{out}/condition_coverage.json")
    assert File.file?("#{out}/index.html")
  end

  test '6rTS4a', %w(
  | the pages rendered later from the JSON report alone,
  | by a render that recorded nothing, are the very pages
  | the recording run wrote, fixed leaves and gaps and all
  ) do
    dir = Dir.mktmpdir('6rTS4a')
    File.write("#{dir}/gang.rb", <<~RUBY)
      module Gang6rTS4a
        LIMIT = 6
        def self.ok?(id) = !id.empty?
        def self.gang?(id) = ok?(id) && id.size == LIMIT
        def self.limit(n) = n || LIMIT
      end
    RUBY
    live = "#{dir}/live"
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    ConditionCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir live
      report :html
    end
    require "#{dir}/gang.rb"
    Gang6rTS4a.gang?('Kp9sA2')
    Gang6rTS4a.limit(nil)
    exit_report.call

    later = "#{dir}/later"
    FileUtils.mkdir_p(later)
    FileUtils.cp("#{live}/condition_coverage.json", later)
    config = ConditionCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir later
      report :html
    end
    ConditionCoverage::Render.from_json(config)

    %w(index.html files/gang.rb.html).each do |page|
      expected = File.read("#{live}/#{page}")
      assert_equal expected, File.read("#{later}/#{page}"), page
    end
  end

  test '6rTS50', %w(
  | starting a second time swaps the configuration silently,
  | with no warning that the load hook was redefined
  ) do
    on_exit = ->(&_report) {}
    assert_silent do
      ConditionCoverage.start(on_exit:) { root '/app' }
      ConditionCoverage.start(on_exit:) { root '/app' }
    end
  end
end
