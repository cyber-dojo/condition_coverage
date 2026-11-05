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
  | Its totals give decisions as [taken, possible]: [1, 3],
  | and methods the same, fee's card being the one ?: row.
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
    totals = { 'decisions' => [1, 3], 'methods' => [1, 3] }
    assert_equal totals, json['totals']
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
  | Within each decision: 2 / 4 50%, one of each if's two.
  | Within each method: 5 / 8 63%, fee's card: its two
  | 1-path statements reached and one of each if's two, and,
  | in the ifs' thens, member's write reached, big's not.
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
    end
    require "#{dir}/fee.rb"
    Fee6rTS4f.fee(true, false)
    exit_report.call

    index = REXML::Document.new(File.read("#{dir}/index.html"))
    total = index.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '2', '2', '/ 4', '50%', '5', '/ 8', '63%']
    assert_equal(expected, total.map { text_of(_1) })
  end

  test '6rTS4h', %w(
  | Example: report :html with group 'Models', 'models/*.rb', of
  | covered files models/crew.rb and lib/zip.rb
  | index.html has a tab for All files, Models, and Ungrouped.
  | The Models tab's table lists models/crew.rb alone.
  | The JSON report's totals have each group's own too: Models
  | took none of crew?'s 3 paths, within its decision or its
  | method.
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
    groups = {
      'Models' => { 'decisions' => [0, 3], 'methods' => [0, 3] }
    }
    assert_equal groups, json['totals']['groups']
  end

  test '6rTS4n', %w(
  | Example: report :html with group 'Models', 'models/*.rb',
  | and lib/zip.rb the only covered file
  | No covered file is in the Models group.
  | So the Models tab's Total row shows 0 sites and - paths.
  | The - is titled no decisions, saying why.
  | The JSON report's Models totals are [0, 0], within
  | decisions and within methods.
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
    assert_equal ['Total', '0', '0', '/ 0', '-'], total
    none = index.elements["#{xpath}[5]"].attributes['title']
    assert_equal 'no decisions', none
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    groups = {
      'Models' => { 'decisions' => [0, 0], 'methods' => [0, 0] }
    }
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
    end
    require "#{dir}/items.rb"
    orders = [nil, { basket: [1] }, [2], { basket: 'x' }]
    items = orders.map { |order| Items6rTS4p.items_of(order) }
    assert_equal [[], [1], [2], []], items
    assert_output('', '') { exit_report.call }
  end

  test '6rTS4q', %w(
  | Example: measure :decisions, :methods, fee with two ifs
  | called once, with true then false, then a render of the
  | run's JSON report into another dir
  | The JSON report holds the statements reached too.
  | So the render's index has the same Total row as the run's.
  | Within each decision: 2 / 4 50%.
  | Within each method: 5 / 8 63%, member's write in its then
  | reached too.
  ) do
    dir = Dir.mktmpdir('6rTS4q')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS4q
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
    live = "#{dir}/live"
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir live
      report :html
    end
    require "#{dir}/fee.rb"
    Fee6rTS4q.fee(true, false)
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

    index = REXML::Document.new(File.read("#{later}/index.html"))
    total = index.elements.to_a('//tfoot/tr/td')
    expected = ['Total', '2', '2', '/ 4', '50%', '5', '/ 8', '63%']
    assert_equal(expected, total.map { text_of(_1) })
  end

  test '6rTS4r', %w(
  | Example: measure :decisions, :methods, fee with two ifs,
  | a report after fee(true, false), another after
  | fee(false, false) too, then a render of both reports
  | The render merges the paths and reaches of every report.
  | So member was taken both ways, big false only, both
  | 1-path statements reached, and member's write in its
  | then reached, big's not.
  | Within each method: 6 / 8 75%, not the first report's 5.
  ) do
    dir = Dir.mktmpdir('6rTS4r')
    File.write("#{dir}/fee_runs.rb", <<~RUBY)
      module Fee6rTS4r
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
    reports = %w(first second).map { |run| "#{dir}/#{run}" }
    exit_reports = reports.map do |out|
      exit_report = nil
      on_exit = ->(&block) { exit_report = block }
      PathCoverage.start(on_exit:) do
        root dir
        cover '*.rb'
        coverage_dir out
      end
      exit_report
    end
    require "#{dir}/fee_runs.rb"
    Fee6rTS4r.fee(true, false)
    assert_output(/path never taken/, '') { exit_reports[0].call }
    Fee6rTS4r.fee(false, false)
    assert_output(/path never taken/, '') { exit_reports[1].call }

    later = "#{dir}/later"
    FileUtils.mkdir_p(later)
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir later
      report :html
    end
    jsons = reports.map { |out| "#{out}/path_coverage.json" }
    PathCoverage::Render.from_json(config, jsons)

    index = REXML::Document.new(File.read("#{later}/index.html"))
    total = index.elements.to_a('//tfoot/tr/td')
    methods = total.map { text_of(_1) }.last(3).join(' ')
    assert_equal '6 / 8 75%', methods
  end

  test '6rTS4t', %w(
  | Example: store[key] ||= key.upcase and name &&= name.strip,
  | each called once skipping its right side and once not
  | Each is a site, its one leaf its target.
  | The target is never read again: its outcome follows from
  | whether the right side ran.
  | ||= runs it when the target is false, &&= when true.
  | Both paths of each were taken, so there are no gaps.
  | The values are those of the uninstrumented code.
  ) do
    dir = Dir.mktmpdir('6rTS4t')
    File.write("#{dir}/cache_writes.rb", <<~RUBY)
      module Cache6rTS4t
        def self.fetch(store, key)
          store[key] ||= key.upcase
        end
        def self.trim(name)
          name &&= name.strip
          name
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/cache_writes.rb"
    fetched = [{}, { 'a' => 'B' }].map do |store|
      Cache6rTS4t.fetch(store, 'a')
    end
    trimmed = [' x ', nil].map { |name| Cache6rTS4t.trim(name) }
    assert_equal [%w(A B), ['x', nil]], [fetched, trimmed]
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    taken = %w(cache_writes.rb:3:4 cache_writes.rb:6:4).to_h do |site|
      [site, json['paths'][site]['taken']]
    end
    both = [{ 'path' => [true], 'count' => 1 },
            { 'path' => [false], 'count' => 1 }]
    expected = {
      'cache_writes.rb:3:4' => both, 'cache_writes.rb:6:4' => both
    }
    assert_equal expected, taken
  end

  test '6rTS4u', %w(
  | Example: store[:size] ||= 0, called only with an empty store
  | Its target was false each time, so its right side ran.
  | So the path with its target true is a gap.
  ) do
    dir = Dir.mktmpdir('6rTS4u')
    File.write("#{dir}/fill_writes.rb", <<~RUBY)
      module Fill6rTS4u
        def self.fill(store)
          store[:size] ||= 0
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/fill_writes.rb"
    assert_equal 0, Fill6rTS4u.fill({})
    gap = "fill_writes.rb:3:4 path never taken: `store[:size]` true\n"
    assert_output(gap, '') { exit_report.call }
  end

  test '6rTS4v', %w(
  | Example: ||= on a constant, an instance variable with a command
  | call on its right, an attribute, a class variable and a global
  | Each is a site, and the rewritten code still loads and runs.
  | clock and grow, called twice, take both paths of each.
  | LIMIT ||= 6 runs once, as the module loads, so its target
  | true is the one gap.
  ) do
    dir = Dir.mktmpdir('6rTS4v')
    File.write("#{dir}/memo_writes.rb", <<~RUBY)
      module Memo6rTS4v
        LIMIT ||= 6
        @@count = nil
        class << self
          attr_accessor :size
        end
        def self.clock
          @clock ||= Time.at 0
        end
        def self.grow(n)
          self.size ||= n
          @@count ||= 0
          $memo6rTS4v ||= n
          [size, @@count, $memo6rTS4v]
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/memo_writes.rb"
    clocks = 2.times.map { Memo6rTS4v.clock }
    grown = [3, 5].map { |n| Memo6rTS4v.grow(n) }
    assert_equal [[Time.at(0)] * 2, [[3, 0, 3]] * 2], [clocks, grown]
    gap = "memo_writes.rb:2:2 path never taken: `LIMIT` true\n"
    assert_output(gap, '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    sites = %w(2:2 8:4 11:4 12:4 13:4).map { "memo_writes.rb:#{_1}" }
    counts = sites.to_h do |site|
      [site, json['paths'][site]['taken'].map { _1['count'] }]
    end
    expected = sites.to_h { |site| [site, [1, 1]] }
    expected['memo_writes.rb:2:2'] = [0, 1]
    assert_equal expected, counts
  end

  test '6rTS4w', %w(
  | Example: @port ||= Integer(text) rescue 80, a rescue modifier
  | on the right of ||=, called with 'x' then '8080'
  | The rewritten code still loads, the modifier needing
  | parentheses to be an argument.
  | It returns what the same code, uninstrumented, returns.
  | 'x' runs the right side, which rescues to 80; '8080' finds
  | @port set and skips it. So both paths are taken: no gaps.
  ) do
    dir = Dir.mktmpdir('6rTS4w')
    source = lambda do |name|
      <<~RUBY
        module #{name}
          def self.port(text)
            @port ||= Integer(text) rescue 80
          end
        end
      RUBY
    end
    File.write("#{dir}/port_writes.rb", source.call('Port6rTS4w'))
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/port_writes.rb"
    eval(source.call('Plain6rTS4w')) # rubocop:disable Security/Eval
    texts = %w(x 8080)
    plain = texts.map { |text| Plain6rTS4w.port(text) }
    actual = texts.map { |text| Port6rTS4w.port(text) }
    assert_equal [[80, 80], plain], [actual, actual]
    assert_output('', '') { exit_report.call }
  end

  test '6rTS4x', %w(
  | Example: user&.account&.owner, called with no user, a user
  | with no account, and a user whose account has an owner
  | The chain is one site, named where it starts.
  | Its leaves are its receivers, user and user&.account.
  | Each is nil or not nil, as &. calls on anything not nil,
  | false included.
  | A nil receiver skips the rest of the chain, so the leaves
  | after it are not reached.
  | All three paths are taken, so there are no gaps.
  ) do
    dir = Dir.mktmpdir('6rTS4x')
    File.write("#{dir}/safe_owner.rb", <<~RUBY)
      module Owner6rTS4x
        User = Struct.new(:account)
        def self.owner(user)
          user&.account&.owner
        end
        Account = Struct.new(:owner)
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/safe_owner.rb"
    user = Owner6rTS4x::User
    users = [nil, user.new(nil), user.new(Owner6rTS4x::Account.new('kim'))]
    owners = users.map { |each| Owner6rTS4x.owner(each) }
    assert_equal [nil, nil, 'kim'], owners
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    expected = [
      { 'path' => ['not nil', 'not nil'], 'count' => 1 },
      { 'path' => ['not nil', 'nil'], 'count' => 1 },
      { 'path' => ['nil', nil], 'count' => 1 }
    ]
    assert_equal expected, json['paths']['safe_owner.rb:4:4']['taken']
  end

  test '6rTS4y', %w(
  | Example: user&.account&.owner, called only with a user whose
  | account has an owner
  | Each path with a nil receiver is a gap, naming each
  | receiver it reaches, nil or not nil.
  ) do
    dir = Dir.mktmpdir('6rTS4y')
    File.write("#{dir}/safe_gaps.rb", <<~RUBY)
      module Gaps6rTS4y
        User = Struct.new(:account)
        def self.owner(user)
          user&.account&.owner
        end
        Account = Struct.new(:owner)
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/safe_gaps.rb"
    account = Gaps6rTS4y::Account.new('kim')
    assert_equal 'kim', Gaps6rTS4y.owner(Gaps6rTS4y::User.new(account))
    never = 'safe_gaps.rb:4:4 path never taken:'
    gaps = [
      "#{never} `user` not nil, `user&.account` nil",
      "#{never} `user` nil"
    ].map { "#{_1}\n" }.join
    assert_output(gaps, '') { exit_report.call }
  end

  test '6rTS4z', %w(
  | Example: ok && user&.admin?, called with ok false, then ok
  | true and no user, a user not an admin, and an admin
  | The chain folds into the && site, as one expression.
  | Its leaves follow ok's: user, nil or not nil, then the
  | chain's value, true or false, when every receiver was not
  | nil.
  | So the four calls take the site's four paths.
  | The popout shows the chain's rows under its &. as user then
  | admin?, so the &. is not shown twice.
  | user's cells are a disc for not nil and an empty set for nil.
  | Each is titled not nil or nil, for its hover text.
  ) do
    dir = Dir.mktmpdir('6rTS4z')
    File.write("#{dir}/safe_admin.rb", <<~RUBY)
      module Admin6rTS4z
        User = Struct.new(:role) do
          def admin? = role == :admin
        end
        def self.admin?(ok, user)
          ok && user&.admin?
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
    end
    require "#{dir}/safe_admin.rb"
    user = Admin6rTS4z::User
    calls = [[false, nil], [true, nil], [true, user.new(:dev)],
             [true, user.new(:admin)]]
    answers = calls.map { |ok, each| Admin6rTS4z.admin?(ok, each) }
    assert_equal [false, nil, false, true], answers
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    taken = json['paths']['safe_admin.rb:6:4']['taken']
    assert_equal([1, 1, 1, 1], taken.map { _1['count'] })
    page = File.read("#{dir}/files/safe_admin.rb.html")
    tree = REXML::Document.new(page).elements["//*[@id='tree-6']"]
    rows = tree.elements.to_a('.//*[@data-operand]')
    texts = rows.map { text_of(_1.elements['*[@data-text]']) }
    assert_equal ['ok', 'user', 'admin?'], texts
    cells = rows[1].elements.to_a('*[@data-cell]').map { text_of(_1) }
    disc, empty = [0x25CF, 0x2205].map { [_1].pack('U') }
    assert_equal [disc, disc, empty, ''], cells
    titles = rows[1].elements.to_a('*[@data-cell]').map do |cell|
      cell.attributes['title']
    end
    assert_equal ['not nil', 'not nil', 'nil', nil], titles
  end

  test '6rTS5a', %w(
  | Example: if user&.admin?, called with no user, a user not an
  | admin, and an admin
  | The chain folds into the if site as its predicate.
  | So the three calls take its three paths: user nil, and
  | user not nil with admin? true or false.
  ) do
    dir = Dir.mktmpdir('6rTS5a')
    File.write("#{dir}/safe_label.rb", <<~RUBY)
      module Label6rTS5a
        User = Struct.new(:role) do
          def admin? = role == :admin
        end
        def self.label(user)
          if user&.admin?
            :admin
          else
            :user
          end
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/safe_label.rb"
    user = Label6rTS5a::User
    users = [nil, user.new(:dev), user.new(:admin)]
    labels = users.map { |each| Label6rTS5a.label(each) }
    assert_equal %i[user user admin], labels
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    taken = json['paths']['safe_label.rb:6:4']['taken']
    assert_equal([1, 1, 1], taken.map { _1['count'] })
  end

  test '6rTS5b', %w(
  | Example: box&.size ||= 3, called with no box, a box with no
  | size and a box of size 5
  | With no box, the whole write is skipped: its right side
  | does not run, yet the target was not found set either.
  | So the write is no site, rather than one reporting its
  | target set when it was never looked at.
  ) do
    dir = Dir.mktmpdir('6rTS5b')
    File.write("#{dir}/safe_write.rb", <<~RUBY)
      module Fill6rTS5b
        Box = Struct.new(:size)
        def self.fill(box)
          box&.size ||= 3
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/safe_write.rb"
    box = Fill6rTS5b::Box
    boxes = [nil, box.new(nil), box.new(5)]
    sizes = boxes.map { Fill6rTS5b.fill(_1) }
    assert_equal [nil, 3, 5], sizes
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    assert_equal({}, json.fetch('paths', {}))
  end

  test '6rTS5d', %w(
  | Example: ids.any? { |id| id.odd? }, standing alone, called with
  | no ids, one odd, one even, an even then an odd, and two even
  | It is a site of its own, being no part of a larger expression.
  | The five calls take its five paths, so there are no gaps.
  ) do
    dir = Dir.mktmpdir('6rTS5d')
    File.write("#{dir}/found_odd.rb", <<~RUBY)
      module Found6rTS5d
        def self.found?(ids)
          ids.any? { |id| id.odd? }
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/found_odd.rb"
    calls = [[], [1], [2], [2, 3], [2, 4]]
    found = calls.map { |ids| Found6rTS5d.found?(ids) }
    assert_equal [false, true, false, true, false], found
    assert_output('', '') { exit_report.call }
  end

  test '6rTS5e', %w(
  | Example: ids.select { |id| id.odd? }.any? &&
  | ids.all? { |id| id > 0 }
  | Both block calls fold into the && site, as one expression.
  | The select sits inside the leaf ids.select { ... }.any?, so
  | the popout shows the select's rows, headed select {, then
  | the leaf's own row, }.any?, so they read as the code does.
  | The all? is the &&'s operand itself, so the popout shows it
  | as a nested condition, its value following from its path.
  ) do
    dir = Dir.mktmpdir('6rTS5e')
    File.write("#{dir}/both_html.rb", <<~RUBY)
      module Both6rTS5e
        def self.both?(ids)
          ids.select { |id| id.odd? }.any? && ids.all? { |id| id > 0 }
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
    end
    require "#{dir}/both_html.rb"
    answers = [[1], [2], [1, -1]].map { |ids| Both6rTS5e.both?(ids) }
    assert_equal [true, false, false], answers
    assert_output('', '') { exit_report.call }

    page = File.read("#{dir}/files/both_html.rb.html")
    tree = REXML::Document.new(page).elements["//*[@id='tree-3']"]
    operators = tree.elements.to_a('.//*[@data-operator]')
    expected = ['&&', 'select {', 'all?']
    assert_equal(expected, operators.map { text_of(_1) })
    texts = tree.elements.to_a('.//*[@data-operand]/*[@data-text]')
    expected = ['ids', 'id.odd?', '}.any?', 'ids', 'id > 0']
    assert_equal(expected, texts.map { text_of(_1) })
  end

  test '6rTS5c', %w(
  | Example: lookup(id)&.rename 'kim', a chain whose first call
  | has no receiver and whose last is a command call, called
  | with an id found and one not
  | The rewritten code still loads, the command parenthesised.
  | Both paths are taken: lookup(id) nil, and not nil.
  ) do
    dir = Dir.mktmpdir('6rTS5c')
    File.write("#{dir}/safe_rename.rb", <<~RUBY)
      module Rename6rTS5c
        User = Struct.new(:name) do
          def rename(name)
            self.name = name
          end
        end
        USERS = { 1 => User.new('al') }.freeze
        def self.lookup(id) = USERS[id]
        def self.rename(id)
          lookup(id)&.rename 'kim'
        end
      end
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/safe_rename.rb"
    names = [2, 1].map { |id| Rename6rTS5c.rename(id) }
    assert_equal [nil, 'kim'], names
    assert_output('', '') { exit_report.call }

    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    taken = json['paths']['safe_rename.rb:10:4']['taken']
    assert_equal([1, 1], taken.map { _1['count'] })
  end

  test '6rTS48', %w(
  | Example: report :html, and crew? called once
  | The exit report writes index.html into coverage_dir.
  | It writes a page per covered file too, eg crew.rb.html.
  | Each site on the page counts the paths it took.
  | It prints no gaps, since :gaps was not chosen.
  | index.html's Total row shows 1 / 3 33% within each
  | decision, and 2 / 4 50% within each method: ok?'s one row
  | reached, and one of crew?'s && row's three paths taken.
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
    expected = ['Total', '1', '1', '/ 3', '33%', '2', '/ 4', '50%']
    assert_equal(expected, total.map { text_of(_1) })
    page = REXML::Document.new(File.read("#{dir}/files/crew.rb.html"))
    tree = "//div[@class='tree']//*[@data-count]"
    counts = page.elements.to_a(tree)
    assert_equal(%w(0 0 *), counts.map { |count| text_of(count) })
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
  | fee is called once, with member true and big false.
  | The exit report prints each if's path never taken, eg
  | `member` false.
  | The JSON report's totals are [taken, possible]:
  | decisions [2, 4], one path of each if's two.
  | methods [5, 8], fee's card: its two 1-path statements
  | reached, one of each if's two, and, in the ifs' thens,
  | member's write reached, big's not.
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
    end
    require "#{dir}/fee.rb"
    assert_equal 95, Fee6rTS41.fee(true, false)
    expected = [
      'fee.rb:4:4 path never taken: `member` false',
      'fee.rb:7:4 path never taken: `big` true'
    ].join("\n")
    assert_output("#{expected}\n") { report.call }
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    totals = { 'decisions' => [2, 4], 'methods' => [5, 8] }
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
  | There are two sites: the if, with the any? folded into its
  | predicate, and the && in the block, a new scope.
  | led? is called with [], ['Lx'], and ['ab', 'cd'].
  | It still returns :not, :led, :not.
  | The exit report prints the paths each site never took.
  | Eg the if never had `ids` 1 item with the block false.
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
      "led.rb:3:4 path never taken: `ids` 1 item, #{block} false",
      "led.rb:3:4 path never taken: `ids` 2+ items, #{block} true",
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
  | true then false
  | At exit it prints a line per total, as SimpleCov prints its
  | line and branch coverage.
  | Within decisions: 2 / 4, one of each if's two paths.
  | Within methods: 5 / 8, fee's card, member's write in its
  | then reached, big's not.
  ) do
    dir = Dir.mktmpdir('6rTS4k')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS4k
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
    end
    require "#{dir}/fee.rb"
    Fee6rTS4k.fee(true, false)
    printed = capture_io { exit_report.call }.first
    decisions = "Path coverage within decisions: 2 / 4 (50.00%)\n"
    methods = "Path coverage within methods: 5 / 8 (62.50%)\n"
    assert_equal decisions + methods, printed
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

  test '6rTS51', %w(
  | Example: a run with ignore '||=' of @m ||= a && b
  | Its JSON report names ||= as ignored.
  | A render from it, ignoring ||= too, prints the gaps the
  | run printed: those of the && alone.
  ) do
    dir = Dir.mktmpdir('6rTS51')
    File.write("#{dir}/memo.rb", <<~RUBY)
      module Memo6rTS51
        def self.m(a, b) = (@m ||= a && b)
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    settings = proc do
      root dir
      cover '*.rb'
      coverage_dir dir
      ignore '||='
    end
    PathCoverage.start(on_exit:, &settings)
    require "#{dir}/memo.rb"
    Memo6rTS51.m(true, true)
    live, = capture_io { report.call }
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    assert_equal ['||='], json['ignored']
    config = PathCoverage::Configuration.new(&settings)
    later, = capture_io { PathCoverage::Render.from_json(config) }
    never = 'memo.rb:2:29 path never taken: `a`'
    expected = "#{never} true, `b` false\n#{never} false\n"
    assert_equal [expected, expected], [live, later]
  end

  test '6rTS52', %w(
  | Example: u.name&.size with treat 'name', as: :present,
  | called with a u whose name is nil
  | The treatment was wrong: name was nil.
  | The exit report says so, naming the path it ruled out,
  | rather than dropping that path unseen.
  ) do
    dir = Dir.mktmpdir('6rTS52')
    File.write("#{dir}/size.rb", <<~RUBY)
      module Size6rTS52
        def self.of(u) = u.name&.size
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      treat 'name', as: :present
    end
    require "#{dir}/size.rb"
    named = Struct.new(:name)
    sizes = [named.new('kim'), named.new(nil)].map do |u|
      Size6rTS52.of(u)
    end
    assert_equal [3, nil], sizes
    expected = 'size.rb:2:19 path taken that a treatment rules ' \
               "out: `u.name` nil\n"
    assert_output(expected) { report.call }
  end

  test '6rTS53', %w(
  | Example: u.name&.size with treat 'name', as: :present, a
  | name nil in each of two runs
  | Each JSON report holds the path the treatment ruled out.
  | A render from both says so, rather than dropping it.
  ) do
    dir = Dir.mktmpdir('6rTS53')
    File.write("#{dir}/size.rb", <<~RUBY)
      module Size6rTS53
        def self.of(u) = u.name&.size
      end
    RUBY
    settings = proc do |out|
      proc do
        root dir
        cover '*.rb'
        coverage_dir out
        treat 'name', as: :present
      end
    end
    outs = %w(first second).map { |run| "#{dir}/#{run}" }
    reports = outs.map do |out|
      report = nil
      on_exit = ->(&block) { report = block }
      PathCoverage.start(on_exit:, &settings.call(out))
      report
    end
    require "#{dir}/size.rb"
    nameless = Struct.new(:name).new(nil)
    reports.each do |report|
      Size6rTS53.of(nameless)
      capture_io { report.call }
    end
    jsons = outs.map { |out| "#{out}/path_coverage.json" }
    outside = JSON.parse(File.read(jsons[0]))['outside']
    ruled_out = outside.transform_values do |all|
      all.map { _1['path'] }
    end
    assert_equal({ 'size.rb:2:19' => [['nil']] }, ruled_out)
    config = PathCoverage::Configuration.new(&settings.call(dir))
    later, = capture_io { PathCoverage::Render.from_json(config, jsons) }
    line = 'size.rb:2:19 path taken that a treatment rules out: ' \
           "`u.name` nil\n"
    assert_includes later, line
  end

  test '6rTS54', %w(
  | Example: ids.select { |i| i.odd? }.any? && c with treat
  | 'any?', as: :nonempty, called on each of its paths
  | any? true with select keeping nothing can never happen.
  | So no such path is listed as never taken.
  | Every possible path was taken, so nothing is printed.
  ) do
    dir = Dir.mktmpdir('6rTS54')
    File.write("#{dir}/odds.rb", <<~RUBY)
      module Odds6rTS54
        def self.k(ids, c) = ids.select { |i| i.odd? }.any? && c
      end
    RUBY
    report = nil
    on_exit = ->(&block) { report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      treat 'any?', as: :nonempty
    end
    require "#{dir}/odds.rb"
    calls = [
      [[], true], [[1], true], [[1], false], [[2], true],
      [[1, 3], true], [[1, 3], false], [[2, 4], true],
      [[1, 2], true], [[1, 2], false]
    ]
    calls.each { |ids, c| Odds6rTS54.k(ids, c) }
    assert_output('') { report.call }
  end

  test '6rTS55', %w(
  | Example: user&.account&.owner, called with no user, and
  | with a user whose account has an owner
  | The popout shows the chain's rows as user, account, then
  | owner, so they read as the code does.
  | owner is ticked on the one path that called it.
  ) do
    dir = Dir.mktmpdir('6rTS55')
    File.write("#{dir}/owner.rb", <<~RUBY)
      module Owner6rTS55
        def self.of(user) = user&.account&.owner
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
    require "#{dir}/owner.rb"
    account = Struct.new(:owner).new('kim')
    users = [nil, Struct.new(:account).new(account)]
    assert_equal([nil, 'kim'], users.map { Owner6rTS55.of(_1) })
    exit_report.call

    page = File.read("#{dir}/files/owner.rb.html")
    tree = REXML::Document.new(page).elements["//*[@id='tree-2']"]
    rows = tree.elements.to_a('.//*[@data-operand]')
    texts = rows.map { text_of(_1.elements['*[@data-text]']) }
    assert_equal %w(user account owner), texts
    cells = rows.last.elements.to_a('*[@data-cell]')
    assert_includes cells.map { text_of(_1) }, [0x2713].pack('U')
  end

  test '6rTS6a', %w(
  | Example: ship, a write then a value, and zero, an endless
  | def of 0, measured within methods, ship called twice and
  | zero once
  | Each statement that is no site is counted each time it
  | runs, by its name.
  | Each method returns what the same code, uninstrumented,
  | returns.
  ) do
    dir = Dir.mktmpdir('6rTS6a')
    source = lambda do |name|
      <<~RUBY
        module #{name}
          def self.ship(order)
            box = order * 2
            box
          end
          def self.zero = 0
        end
      RUBY
    end
    File.write("#{dir}/ship6a.rb", source.call('Ship6rTS6a'))
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    require "#{dir}/ship6a.rb"
    eval(source.call('Plain6rTS6a')) # rubocop:disable Security/Eval
    calls = ->(mod) { [mod.ship(3), mod.ship(4), mod.zero] }
    plain = calls.call(Plain6rTS6a)
    actual = calls.call(Ship6rTS6a)
    assert_equal [[6, 8, 0], plain], [actual, actual]
    reached = PathCoverage.recorder.reached.select do |name, _|
      name.start_with?('ship6a.rb:')
    end
    expected = {
      'ship6a.rb:3:4' => 2, 'ship6a.rb:4:4' => 2,
      'ship6a.rb:6:18' => 1
    }
    assert_equal expected, reached
    assert_output('', '') { exit_report.call }
  end

  test '6rTS6b', %w(
  | Example: ship, a write, a return if empty, then a value,
  | measured within methods, called once with a full order
  | Its card in the HTML report shows each row's taken, and
  | its JSON report holds each statement's reaches.
  | The write and the value were reached, so each has its 1
  | path taken; the if's then never ran, so it has 1 of 2.
  ) do
    dir = Dir.mktmpdir('6rTS6b')
    File.write("#{dir}/ship6b.rb", <<~RUBY)
      module Ship6rTS6b
        def self.ship(order)
          box = order * 2
          return 0 if box.zero?
          box
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
    end
    require "#{dir}/ship6b.rb"
    Ship6rTS6b.ship(3)
    exit_report.call
    page = File.read("#{dir}/files/ship6b.rb.html")
    expected = [
      %w(ship 3), %w(line:col taken),
      %w(3:04 1), %w(4:13 1), %w(5:04 1)
    ]
    assert_equal expected, card_taken(page, 2)
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    reached = json['reached'].select { _1.start_with?('ship6b.rb:') }
    expected = { 'ship6b.rb:3:4' => 1, 'ship6b.rb:5:4' => 1 }
    assert_equal expected, reached
  end

  test '6rTS6c', %w(
  | Example: label, a ternary whose then arm is an && chain,
  | and mark, an if whose then arm holds only a comment
  | Each arm's row in its tree is located in the source,
  | data-at, but the empty then arm, as it has no code.
  | The && in label's then arm is located too, its operands
  | with it.
  ) do
    dir = Dir.mktmpdir('6rTS6c')
    File.write("#{dir}/label6c.rb", <<~RUBY)
      module Label6rTS6c
        def self.label(sale, cheap)
          sale ? (cheap && 'bargain') : 'full price'
        end

        def self.mark(ok)
          if ok
            # nothing to mark
          else
            'unmarked'
          end
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
    end
    require "#{dir}/label6c.rb"
    Label6rTS6c.label(true, true)
    Label6rTS6c.mark(false)
    exit_report.call
    page = REXML::Document.new(File.read("#{dir}/files/label6c.rb.html"))
    located = lambda do |tree, kind|
      rows = page.elements.to_a("//*[@id='#{tree}']//*[@#{kind}]")
      rows.map { !_1.attributes['data-at'].nil? }
    end
    assert_equal [true, true], located.call('tree-3', 'data-arm')
    assert_equal [true] * 3, located.call('tree-3', 'data-operand')
    assert_equal [false, true], located.call('tree-7', 'data-arm')
  end

  test '6rTS6d', %w(
  | Example: ship, an if then a value, measured within methods,
  | called once with a paid order
  | Its card folds the if's tree under the if's row.
  | The fold holds the same rows as the if's tree within each
  | decision: its operator, its 2 path counts, the one never
  | taken first, and its operands.
  ) do
    dir = Dir.mktmpdir('6rTS6d')
    File.write("#{dir}/ship6d.rb", <<~RUBY)
      module Ship6rTS6d
        def self.ship(order)
          if order[:paid]
            order[:packed] = true
          end
          order
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
    end
    require "#{dir}/ship6d.rb"
    Ship6rTS6d.ship({ paid: true })
    exit_report.call
    page = REXML::Document.new(File.read("#{dir}/files/ship6d.rb.html"))
    fold = "//div[@class='fold'][@data-site='ship6d.rb:3:4']"
    site = page.elements["#{fold}/div[@class='site']"]
    counts = page.elements.to_a("#{fold}//*[@data-count]")
    assert_equal(%w(0 *), counts.map { text_of(_1) })
    tree = page.elements["//div[@id='tree-3']/div[@class='site']"]
    assert_equal tree.to_s, site.to_s
  end

  test '6rTS6e', %w(
  | Example: rate.rb, a ?: at its top level, with no RATE set,
  | and fee, a def of a ?:, called once with big true
  | The top level's ?: is on no card, outside every def, so
  | its paths are in the methods total as they are: 1 of 2.
  | So the methods total is fee's card's 1 of 2 and the top
  | level's 1 of 2: [2, 4].
  ) do
    dir = Dir.mktmpdir('6rTS6e')
    File.write("#{dir}/rate.rb", <<~RUBY)
      RATE6rTS6e = ENV.key?('RATE6rTS6e') ? 2 : 1
      module Fee6rTS6e
        def self.fee(big) = big ? 10 : 5
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
    require "#{dir}/rate.rb"
    Fee6rTS6e.fee(true)
    exit_report.call
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    assert_equal [2, 4], json['totals']['methods']
  end

  test '6rTS6f', %w(
  | Example: rate.rb, a ?: at its top level, with no RATE set
  | Its page has a top card for line 1, as a method has a card,
  | titled file, its scope: one ?: row, 1 of its 2 paths taken.
  ) do
    dir = Dir.mktmpdir('6rTS6f')
    File.write("#{dir}/rate.rb", <<~RUBY)
      RATE6rTS6f = ENV.key?('RATE6rTS6f') ? 2 : 1
    RUBY
    exit_report = nil
    on_exit = ->(&block) { exit_report = block }
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :html
    end
    require "#{dir}/rate.rb"
    exit_report.call
    page = File.read("#{dir}/files/rate.rb.html")
    top = '<div class="pathgrid statements top-level" id="paths-1"'
    assert_includes page, top
    expected = [%w(file 1), %w(line:col taken), %w(1:13 1)]
    assert_equal expected, card_taken(page, 1)
  end

  test '6rTS6g', %w(
  | Example: rate.rb, module Rate holding a ?: outside any
  | method, with no RATE set
  | Its card is titled Rate, its scope, as a method's card is
  | titled by its method.
  ) do
    dir = Dir.mktmpdir('6rTS6g')
    File.write("#{dir}/rate.rb", <<~RUBY)
      module Rate6rTS6g
        RATE = ENV.key?('RATE6rTS6g') ? 2 : 1
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
    require "#{dir}/rate.rb"
    exit_report.call
    page = File.read("#{dir}/files/rate.rb.html")
    expected = [%w(Rate6rTS6g 1), %w(line:col taken), %w(2:09 1)]
    assert_equal expected, card_taken(page, 2)
  end

  test '6rTS6h', %w(
  | Example: rate.rb, class Rate holding a ?: outside any
  | method, with no RATE set
  | Its card is titled Rate, its scope, as a module's is.
  ) do
    dir = Dir.mktmpdir('6rTS6h')
    File.write("#{dir}/rate.rb", <<~RUBY)
      class Rate6rTS6h
        RATE = ENV.key?('RATE6rTS6h') ? 2 : 1
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
    require "#{dir}/rate.rb"
    exit_report.call
    page = File.read("#{dir}/files/rate.rb.html")
    expected = [%w(Rate6rTS6h 1), %w(line:col taken), %w(2:09 1)]
    assert_equal expected, card_taken(page, 2)
  end

  test '6rTS6j', %w(
  | Example: module Fee holding fee, a def of a ?:, called once
  | with big true
  | The JSON report lists fee's card, under its def's site, as
  | its page draws it: its name, first and last lines, and a
  | row per statement, with its paths, how many were taken, and
  | its site, so a reader finds a card's gap without the page.
  ) do
    dir = Dir.mktmpdir('6rTS6j')
    File.write("#{dir}/fee.rb", <<~RUBY)
      module Fee6rTS6j
        def self.fee(big) = big ? 10 : 5
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
    require "#{dir}/fee.rb"
    Fee6rTS6j.fee(true)
    exit_report.call
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    expected = {
      'fee.rb:2:2' => {
        'name' => 'fee', 'first' => 2, 'last' => 2,
        'rows' => [
          { 'at' => '2:22', 'top' => '?:', 'paths' => 2, 'taken' => 1,
            'site' => 'fee.rb:2:22' }
        ]
      }
    }
    assert_equal expected, json['cards']
  end

  test '6rTS6k', %w(
  | Example: module Rate holding a ?: outside any method, with
  | no RATE set
  | The JSON report lists its top card too, under the site of
  | its first line's start, titled Rate, its scope, as its page
  | draws it, so a reader finds a gap outside every def too.
  ) do
    dir = Dir.mktmpdir('6rTS6k')
    File.write("#{dir}/rate.rb", <<~RUBY)
      module Rate6rTS6k
        RATE = ENV.key?('RATE6rTS6k') ? 2 : 1
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
    require "#{dir}/rate.rb"
    exit_report.call
    json = JSON.parse(File.read("#{dir}/path_coverage.json"))
    expected = {
      'rate.rb:2:0' => {
        'name' => 'Rate6rTS6k', 'first' => 2, 'last' => 2,
        'rows' => [
          { 'at' => '2:09', 'top' => '?:', 'paths' => 2, 'taken' => 1,
            'site' => 'rate.rb:2:9' }
        ]
      }
    }
    assert_equal expected, json['cards']
  end

  test '6rTS6m', %w(
  | Example: two starts in one process, eg two tests, each over
  | its own rate.rb, a ?: whose site has the same name in both,
  | each evaluated once, with no RATE set
  | Each start records afresh, so the second run's report counts
  | its own one evaluation, not the first run's too.
  ) do
    dirs = %w(first second).map { |run| Dir.mktmpdir("6rTS6m#{run}") }
    jsons = dirs.map.with_index do |dir, index|
      File.write("#{dir}/rate.rb", <<~RUBY)
        RATE6rTS6m#{index} = ENV.key?('RATE6rTS6m') ? 2 : 1
      RUBY
      exit_report = nil
      on_exit = ->(&block) { exit_report = block }
      PathCoverage.start(on_exit:) do
        root dir
        cover '*.rb'
        coverage_dir dir
      end
      require "#{dir}/rate.rb"
      exit_report.call
      JSON.parse(File.read("#{dir}/path_coverage.json"))
    end
    taken = jsons.last['paths'].values.first['taken']
    assert_equal([0, 1], taken.map { _1['count'] })
  end

  private

  # [label, last cell's text] of each row of the statement card
  # of the def at line first in page.
  def card_taken(page, first)
    card = page[/id="paths-#{first}".*$/]
    card.scan(%r{<div class="prow[^>]*>(.*?)</div>}).map do |(row)|
      texts = row.scan(%r{<span[^>]*>([^<]*)</span>}).flatten
      [texts.first, texts.last]
    end
  end
end
