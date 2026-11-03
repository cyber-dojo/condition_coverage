require_relative 'test_helper'
require 'path_coverage/kernel'
require 'json'
require 'rexml/document'
require 'tmpdir'

class KernelTest < Id58TestBase
  # Its tests swap the configuration of the one global load
  # hook, and capture $stdout.
  serial!

  test '6rTS10', %w(
  | PathCoverage.record, the call rewritten code makes,
  | returns the operand's value and counts it
  | in the one shared recorder
  ) do
    site = 'kernel_test.rb:6rTS10:0' # used by no other test
    kata = { 'id' => 'Kp9sA2' }
    assert_same kata, PathCoverage.record(site, 0, kata)

    expected = { truthy: 1, falsy: 0 }
    actual = PathCoverage.recorder.counts[[site, 0]]
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
    PathCoverage.start(on_exit:) do
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
    counts = PathCoverage.recorder.counts
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
    config = PathCoverage::Configuration.new do
      root covered
      cover '*.rb'
    end
    assert_nil PathCoverage.instrumented(path, config)
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
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/group.rb"
    Group6rTS40.group?('Kp9sA2')
    never = 'group.rb:3:24 path never taken: `ok?(id)`'
    expected = [
      "#{never} true, `id.size == 6` false",
      "#{never} false"
    ].join("\n")
    assert_output("#{expected}\n") { report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    expected = {
      'group.rb:3:24' => [
        { 'truthy' => 1, 'falsy' => 0 },
        { 'truthy' => 1, 'falsy' => 0 }
      ]
    }
    assert_equal expected, json['sites']
  end

  test '6rTS42', %w(
  | a ternary's path is recorded as it runs, so one whose
  | predicate was only ever true lists its false path as a gap
  ) do
    dir = Dir.mktmpdir('6rTS42')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS42
        def self.fee(member) = member ? 5 : 7
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/fee.rb"
    Fee6rTS42.fee(true)
    expected = "fee.rb:2:25 path never taken: `member` false\n"
    assert_output(expected) { report.call }
  end

  test '6rTS43', %w(
  | Example: user[:member] || user[:vip] ? 5 : 7, called once
  | Each evaluation's path through the site is recorded.
  | Each path never taken is printed as a gap.
  | The JSON report has every path's count, and each leaf's
  | span.
  | Its totals give decisions as [taken, possible]: [1, 3].
  | It has no methods total, as :methods is not measured.
  ) do
    dir = Dir.mktmpdir('6rTS43')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS43
        def self.fee(user) = user[:member] || user[:vip] ? 5 : 7
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/fee.rb"
    Fee6rTS43.fee({ member: true })
    never = 'fee.rb:2:23 path never taken: `user[:member]` false'
    expected = [
      "#{never}, `user[:vip]` true",
      "#{never}, `user[:vip]` false"
    ].join("\n")
    assert_output("#{expected}\n") { report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    expected = {
      'fee.rb:2:23' => {
        'leaves' => [%w(2:23 2:36), %w(2:40 2:50)],
        'taken' => [
          { 'path' => [true, nil], 'count' => 1 },
          { 'path' => [false, true], 'count' => 0 },
          { 'path' => [false, false], 'count' => 0 }
        ]
      }
    }
    assert_equal expected, json['paths']
    assert_equal({ 'decisions' => [1, 3] }, json['totals'])
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
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require path
    Team6rTS45.team?('Kp9sA2')
    # A re-read of the file now would find no &&.
    File.write(path, "module Team6rTS45; end\n")
    never = 'team.rb:3:23 path never taken: `ok?(id)`'
    expected = [
      "#{never} true, `id.size == 6` false",
      "#{never} false"
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
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    assert_output("squad.rb:3:24 never reached\n") { report.call }
  end

  test '6rTS4f', %w(
  | Example: report :html, measure :decisions, :methods, and
  | fee with two ifs called once, with true then false
  | index.html's Total row shows both totals.
  | Within each decision: 2 / 4 (50%), one of each if's two.
  | Within each method: 1 / 4 (25%), one of fee's four.
  ) do
    dir = Dir.mktmpdir('6rTS4f')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS4f
        def self.fee(member, big)
          total = 100
          if member
            total -= 5
          end
          if big
            total -= 10
          end
          total
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :html
      measure :decisions, :methods
    end
    require "#{dir}/fee.rb"
    Fee6rTS4f.fee(true, false)
    exit_report.call

    index = REXML::Document.new(File.read("#{dir}/index.html"))
    total = index.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '2', '2 / 4 (50%)', '1 / 4 (25%)']
    assert_equal(expected, total.map { text_of(_1) })
  end

  test '6rTS4h', %w(
  | Example: report :html with group 'Models', 'models/*.rb', of
  | covered files models/crew.rb and lib/zip.rb
  | index.html has a tab for All files, Models, and Ungrouped.
  | The Models tab's table lists models/crew.rb alone.
  | The JSON report's totals have each group's own too: Models
  | took none of crew?'s 3 paths.
  ) do
    dir = Dir.mktmpdir('6rTS4h')
    FileUtils.mkdir_p(%W[#{dir}/models #{dir}/lib])
    File.write("#{dir}/models/crew.rb", "def crew?(a, b) = a && b\n")
    File.write("#{dir}/lib/zip.rb", "def zip?(a, b) = a || b\n")
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '**/*.rb'
      coverage_dir dir
      report :html
      group 'Models', 'models/*.rb'
    end
    exit_report.call

    index = REXML::Document.new(File.read("#{dir}/index.html"))
    tabs = index.elements.to_a("//*[@role='tab']").map { text_of(_1) }
    assert_equal ['All files', 'Models', 'Ungrouped'], tabs
    xpath = "//table[@id='files-1']/tbody/tr/td[1]"
    models = index.elements.to_a(xpath)
    assert_equal(['models/crew.rb'], models.map { text_of(_1) })
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    groups = { 'Models' => { 'decisions' => [0, 3] } }
    assert_equal groups, json['totals']['groups']
  end

  test '6rTS4n', %w(
  | Example: report :html with group 'Models', 'models/*.rb',
  | and lib/zip.rb the only covered file
  | No covered file is in the Models group.
  | So the Models tab's Total row shows 0 sites and - paths.
  | The - is titled no decisions, saying why.
  | The JSON report's Models totals are [0, 0].
  ) do
    dir = Dir.mktmpdir('6rTS4n')
    FileUtils.mkdir_p("#{dir}/lib")
    File.write("#{dir}/lib/zip.rb", "def zip?(a, b) = a || b\n")
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '**/*.rb'
      coverage_dir dir
      report :html
      group 'Models', 'models/*.rb'
    end
    exit_report.call

    index = REXML::Document.new(File.read("#{dir}/index.html"))
    xpath = "//table[@id='files-1']/tfoot/tr/td"
    total = index.elements.to_a(xpath).map { text_of(_1) }
    assert_equal %w(Total 0 -), total
    none = index.elements["#{xpath}[3]"].attributes['title']
    assert_equal 'no decisions', none
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    groups = { 'Models' => { 'decisions' => [0, 0] } }
    assert_equal groups, json['totals']['groups']
  end

  test '6rTS4p', %w(
  | Example: items_of, an if then a ternary, called with nil,
  | { basket: [1] }, [2] and { basket: 'x' }
  | The ternary's predicate is its decision, not its value.
  | So the four calls take all four paths: [F,F], [T,T],
  | [F,T] and [T,F].
  | And each site took every path too.
  | So there are no gaps to print.
  ) do
    dir = Dir.mktmpdir('6rTS4p')
    File.write("#{dir}/items.rb", <<~RUBY)
      module Items6rTS4p
        def self.items_of(order)
          order = order[:basket] if order.is_a?(Hash)
          order.is_a?(Array) ? order : []
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      measure :decisions, :methods
    end
    require "#{dir}/items.rb"
    orders = [nil, { basket: [1] }, [2], { basket: 'x' }]
    items = orders.map { |order| Items6rTS4p.items_of(order) }
    assert_equal [[], [1], [2], []], items
    assert_output('', '') { exit_report.call }
  end

  test '6rTS48', %w(
  | Example: report :html, and crew? called once
  | The exit report writes index.html into coverage_dir.
  | It writes a page per covered file too, eg crew.rb.html.
  | Each site on the page counts the paths it took.
  | It prints no gaps, since :gaps was not chosen.
  | index.html's Total row shows 1 / 3 (33%) within each
  | decision, and no methods cell, as methods are not measured.
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
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :html
    end
    require "#{dir}/crew.rb"
    Crew6rTS48.crew?('Kp9sA2')

    assert_output('', '') { exit_report.call }

    index = REXML::Document.new(File.read("#{dir}/index.html"))
    total = index.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '1', '1 / 3 (33%)']
    assert_equal(expected, total.map { text_of(_1) })
    page = REXML::Document.new(File.read("#{dir}/files/crew.rb.html"))
    counts = page.elements.to_a('//*[@data-count]')
    assert_equal(%w(0 0 1), counts.map { |count| text_of(count) })
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
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir out
      report :html
    end
    exit_report.call

    assert File.file?("#{out}/path_coverage.json")
    assert File.file?("#{out}/index.html")
  end

  test '6rTS4b', %w(
  | starting from the environment covers each of its
  | comma-separated globs under its root, writing the JSON
  | report to its dir and POSTing it to its collector
  ) do
    dir = Dir.mktmpdir('6rTS4b')
    FileUtils.mkdir_p(%W[#{dir}/source #{dir}/lib])
    File.write("#{dir}/source/kata.rb", "def kata?(id) = id\n")
    File.write("#{dir}/lib/team.rb", "def team?(id) = id\n")
    env = {
      'PATH_COVERAGE_ROOT' => dir,
      'PATH_COVERAGE_COVER' => 'source/*.rb,lib/*.rb',
      'PATH_COVERAGE_DIR' => "#{dir}/condition",
      'PATH_COVERAGE_COLLECTOR' => 'http://10.0.0.7:4570/runs'
    }
    on_exit = ->(&_report) {} # this test checks the settings only
    PathCoverage.start_from_env(env, on_exit:)

    config = PathCoverage.config
    actual = [
      config.files, config.json_path,
      config.collector_url, config.reporters
    ]
    expected = [
      ["#{dir}/lib/team.rb", "#{dir}/source/kata.rb"],
      "#{dir}/condition/path_coverage.json",
      'http://10.0.0.7:4570/runs', [:post]
    ]
    assert_equal expected, actual
  end

  test '6rTS4g', %w(
  | Example: PATH_COVERAGE_SKIP=source/vendor/**/*.rb,lib/gen.rb
  | Starting from the environment skips each of its
  | comma-separated skip globs.
  | So only source/kata.rb is covered of the three files.
  ) do
    dir = Dir.mktmpdir('6rTS4g')
    FileUtils.mkdir_p(%W[#{dir}/source/vendor #{dir}/lib])
    File.write("#{dir}/source/kata.rb", "def kata?(id) = id\n")
    File.write("#{dir}/source/vendor/zip.rb", "def zip?(id) = id\n")
    File.write("#{dir}/lib/gen.rb", "def gen?(id) = id\n")
    env = {
      'PATH_COVERAGE_ROOT' => dir,
      'PATH_COVERAGE_COVER' => 'source/**/*.rb,lib/*.rb',
      'PATH_COVERAGE_SKIP' => 'source/vendor/**/*.rb,lib/gen.rb',
      'PATH_COVERAGE_DIR' => "#{dir}/condition",
      'PATH_COVERAGE_COLLECTOR' => 'http://10.0.0.7:4570/runs'
    }
    on_exit = ->(&_report) {} # this test checks the settings only
    PathCoverage.start_from_env(env, on_exit:)
    assert_equal ["#{dir}/source/kata.rb"], PathCoverage.config.files
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
        def self.limit(n) = n || 6
      end
    RUBY
    live = "#{dir}/live"
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
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
    FileUtils.cp("#{live}/path_coverage.json", later)
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir later
      report :html
    end
    PathCoverage::Render.from_json(config)

    %w(index.html files/gang.rb.html).each do |page|
      expected = File.read("#{live}/#{page}")
      assert_equal expected, File.read("#{later}/#{page}"), page
    end
  end

  test '6rTS4m', %w(
  | Example: a run covering crew.rb and gen.rb, then a render of
  | its JSON report, into the same dir, with skip 'gen.rb'
  | The render writes crew.rb's page only.
  | gen.rb's page, from the run before, is removed.
  | So the files dir holds a page for each covered file alone.
  ) do
    dir = Dir.mktmpdir('6rTS4m')
    File.write("#{dir}/crew.rb", <<~RUBY)
      module Crew6rTS4m
        def self.crew?(id) = !id.empty? && id.size == 6
      end
    RUBY
    File.write("#{dir}/gen.rb", <<~RUBY)
      module Gen6rTS4m
        def self.gen?(id) = id.nil? || id.empty?
      end
    RUBY
    out = "#{dir}/reports"
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir out
      report :html
    end
    require "#{dir}/crew.rb"
    require "#{dir}/gen.rb"
    Crew6rTS4m.crew?('Kp9sA2')
    Gen6rTS4m.gen?('Kp9sA2')
    exit_report.call

    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      skip 'gen.rb'
      coverage_dir out
      report :html
    end
    PathCoverage::Render.from_json(config)

    pages = Dir.glob('**/*.html', base: "#{out}/files")
    assert_equal ['crew.rb.html'], pages
  end

  test '6rTS41', %w(
  | Example: fee with if member ... end and if big ... end
  | measure :decisions, :methods is chosen.
  | fee has two decisions, so each call records its path.
  | fee is called once, with member true and big false.
  | The exit report prints each path never taken.
  | First each if's own, as a site, eg `member` false.
  | Then fee's, eg line 4 true, line 7 true.
  | The JSON report's totals are [taken, possible]:
  | decisions [2, 4], one path of each if's two.
  | methods [1, 4], one path of fee's four.
  ) do
    dir = Dir.mktmpdir('6rTS41')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS41
        def self.fee(member, big)
          total = 100
          if member
            total -= 5
          end
          if big
            total -= 10
          end
          total
        end
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      measure :decisions, :methods
    end
    require "#{dir}/fee.rb"
    assert_equal 95, Fee6rTS41.fee(true, false)
    expected = [
      'fee.rb:4:4 path never taken: `member` false',
      'fee.rb:7:4 path never taken: `big` true',
      'fee.rb:2:2 fee path never taken: line 4 true, line 7 true',
      'fee.rb:2:2 fee path never taken: line 4 false, line 7 true',
      'fee.rb:2:2 fee path never taken: line 4 false, line 7 false'
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    totals = { 'decisions' => [2, 4], 'methods' => [1, 4] }
    assert_equal totals, json['totals']
  end

  test '6rTS4c', %w(
  | Example: case x when 1, 2 ... when String ... else ... end
  | kind is called with 2 and with :k.
  | The covered case still picks :small and :other.
  | The exit report prints each path its patterns never took.
  | Eg `1` true, as 1 was never passed.
  ) do
    dir = Dir.mktmpdir('6rTS4c')
    File.write("#{dir}/kind.rb", <<~RUBY)
      module Kind6rTS4c
        def self.kind(x)
          case x
          when 1, 2 then :small
          when String then :text
          else :other
          end
        end
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/kind.rb"
    actual = [Kind6rTS4c.kind(2), Kind6rTS4c.kind(:k)]
    assert_equal %i[small other], actual
    never = 'kind.rb:3:4 path never taken:'
    expected = [
      "#{never} `1` true",
      "#{never} `1` false, `2` false, `String` true"
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
  end

  test '6rTS4d', %w(
  | Example: if ids.any? { |id| id.start_with?('L') && id.size > 1 }
  | There are three sites: the if, the any?, and the &&.
  | led? is called with [], ['Lx'], and ['ab', 'cd'].
  | It still returns :not, :led, :not.
  | The exit report prints the paths each site never took.
  | Eg any? never had `ids` 1 item with its block false.
  ) do
    dir = Dir.mktmpdir('6rTS4d')
    File.write("#{dir}/led.rb", <<~RUBY)
      module Team6rTS4d
        def self.led?(ids)
          if ids.any? { |id| id.start_with?('L') && id.size > 1 }
            :led
          else
            :not
          end
        end
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/led.rb"
    led = [[], ['Lx'], %w(ab cd)].map { |ids| Team6rTS4d.led?(ids) }
    assert_equal %i[not led not], led
    block = "`id.start_with?('L') && id.size > 1`"
    expected = [
      "led.rb:3:11 path never taken: `ids` 1 item, #{block} false",
      "led.rb:3:11 path never taken: `ids` 2+ items, #{block} true",
      'led.rb:3:23 path never taken: ' \
      "`id.start_with?('L')` true, `id.size > 1` false"
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
  end

  test '6rTS4j', %w(
  | Example: ns.filter_map do |n| "n#{n}" unless n.nil? end
  | The block's one expression is a modifier unless.
  | The covered file still loads, and filter_map still keeps
  | ["n1", "n2"] of [1, nil, 2].
  ) do
    dir = Dir.mktmpdir('6rTS4j')
    File.write("#{dir}/names.rb", <<~'RUBY')
      module Names6rTS4j
        def self.names(ns)
          ns.filter_map do |n|
            "n#{n}" unless n.nil?
          end
        end
      end
    RUBY
    on_exit = ->(&_report) {}
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/names.rb"
    assert_equal %w(n1 n2), Names6rTS4j.names([1, nil, 2])
  end

  test '6rTS4k', %w(
  | Example: report :summary, fee with two ifs called once with
  | true then false, measuring decisions, then decisions and
  | methods
  | At exit it prints a line per total, as SimpleCov prints its
  | line and branch coverage.
  | Within decisions: 2 / 4, one of each if's two paths.
  | Within methods, only when methods are measured: 1 / 4.
  ) do
    # Each measure covers a file and module of its own, so neither
    # run redefines the other's fee.
    measures = { 'D' => %i[decisions], 'M' => %i[decisions methods] }
    printed = measures.map do |tag, names|
      dir = Dir.mktmpdir("6rTS4k#{tag}")
      File.write("#{dir}/fee.rb", <<~RUBY)
        module Fee6rTS4k#{tag}
          def self.fee(member, big)
            total = 100
            if member
              total -= 5
            end
            if big
              total -= 10
            end
            total
          end
        end
      RUBY
      exit_report = nil
      on_exit = ->(&block) { exit_report = block }
      PathCoverage.start(on_exit:) do
        root dir
        cover '*.rb'
        coverage_dir dir
        report :summary
        measure(*names)
      end
      require "#{dir}/fee.rb"
      Object.const_get("Fee6rTS4k#{tag}").fee(true, false)
      capture_io { exit_report.call }.first
    end
    decisions = "Path coverage within decisions: 2 / 4 (50.00%)\n"
    methods = "Path coverage within methods: 1 / 4 (25.00%)\n"
    assert_equal [decisions, decisions + methods], printed
  end

  test '6rTS4e', %w(
  | Example: ns.select { |n| n.odd? }
  | odds is called with [], [1], and [1, 2].
  | The covered select still keeps [], [1], and [1].
  | The exit report prints the paths never taken.
  | Eg `ns` 2+ items, `n.odd?` all true.
  ) do
    dir = Dir.mktmpdir('6rTS4e')
    File.write("#{dir}/odds.rb", <<~RUBY)
      module Odds6rTS4e
        def self.odds(ns) = ns.select { |n| n.odd? }
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/odds.rb"
    odds = [[], [1], [1, 2]].map { |ns| Odds6rTS4e.odds(ns) }
    assert_equal [[], [1], [1]], odds
    never = 'odds.rb:2:25 path never taken: `ns`'
    expected = [
      "#{never} 1 item, `n.odd?` all false",
      "#{never} 2+ items, `n.odd?` all true",
      "#{never} 2+ items, `n.odd?` all false"
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
  end

  test '6rTS50', %w(
  | starting a second time swaps the configuration silently,
  | with no warning that the load hook was redefined
  ) do
    on_exit = ->(&_report) {}
    assert_silent do
      PathCoverage.start(on_exit:) { root '/app' }
      PathCoverage.start(on_exit:) { root '/app' }
    end
  end
end
