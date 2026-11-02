require_relative 'test_helper'
require 'condition_coverage/configuration'
require 'condition_coverage/json_writer'
require 'condition_coverage/manifest'
require 'condition_coverage/render'
require 'tmpdir'

class RenderTest < Id58TestBase
  test 'Rn5d10', %w(
  | rendering from the JSON reports of several runs
  | reports their merged counts, so only the paths that
  | every run left untaken are listed
  ) do
    dir = Dir.mktmpdir('Rn5d10')
    source = "def kata?(id) = ok?(id) && id.size == 6\n"
    File.write("#{dir}/kata.rb", source)
    sites = ConditionCoverage::Manifest.sites(source, 'kata.rb')
    site = sites.keys.first
    leaves = [%w(1:16 1:23), %w(1:27 1:39)]
    runs = [
      [[{ truthy: 1, falsy: 0 }, { truthy: 0, falsy: 1 }], [0, 1, 0]],
      [[{ truthy: 0, falsy: 1 }, { truthy: 0, falsy: 0 }], [0, 0, 1]]
    ]
    paths = runs.each_with_index.map do |(operands, counts), n|
      taken = [[true, true], [true, false], [false, nil]]
              .zip(counts).map { |path, count| { path:, count: } }
      file = "#{dir}/run#{n}.json"
      report = { site => { leaves:, taken: } }
      writer = ConditionCoverage::JsonWriter
      writer.write({ site => operands }, file, report)
      file
    end
    config = ConditionCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    gap = "#{site} path never taken: " \
          '`ok?(id)` true, `id.size == 6` true'
    assert_output("#{gap}\n", '') do
      ConditionCoverage::Render.from_json(config, paths)
    end
  end

  test 'Rn5d20', %w(
  | a JSON report with no paths, eg from an older version,
  | cannot say which paths were taken, so rendering from it
  | reports every path of each site it reached as never
  | taken, rather than claiming any was
  ) do
    dir = Dir.mktmpdir('Rn5d20')
    source = "def kata?(id) = ok?(id) && id.size == 6\n"
    File.write("#{dir}/kata.rb", source)
    sites = ConditionCoverage::Manifest.sites(source, 'kata.rb')
    site = sites.keys.first
    operands = [{ truthy: 1, falsy: 1 }, { truthy: 1, falsy: 0 }]
    file = "#{dir}/run.json"
    ConditionCoverage::JsonWriter.write({ site => operands }, file)
    config = ConditionCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    never = "#{site} path never taken: `ok?(id)`"
    expected = [
      "#{never} true, `id.size == 6` true",
      "#{never} true, `id.size == 6` false",
      "#{never} false"
    ].join("\n")
    assert_output("#{expected}\n", '') do
      ConditionCoverage::Render.from_json(config, [file])
    end
  end
end
