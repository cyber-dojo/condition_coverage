require_relative 'test_helper'
require 'condition_coverage/configuration'
require 'condition_coverage/json_writer'
require 'condition_coverage/manifest'
require 'condition_coverage/render'
require 'tmpdir'

class RenderTest < Id58TestBase
  test 'Rn5d10', %w(
  | rendering from the JSON reports of several runs
  | reports their merged counts, so only the gaps that
  | every run left are listed
  ) do
    dir = Dir.mktmpdir('Rn5d10')
    source = "def kata?(id) = ok?(id) && id.size == 6\n"
    File.write("#{dir}/kata.rb", source)
    sites = ConditionCoverage::Manifest.sites(source, 'kata.rb')
    site = sites.keys.first
    runs = [
      [{ truthy: 1, falsy: 0 }, { truthy: 0, falsy: 1 }],
      [{ truthy: 0, falsy: 1 }, { truthy: 0, falsy: 0 }]
    ]
    paths = runs.each_with_index.map do |operands, n|
      path = "#{dir}/run#{n}.json"
      ConditionCoverage::JsonWriter.write({ site => operands }, path)
      path
    end
    config = ConditionCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    assert_output("#{site} operand 1 never true\n", '') do
      ConditionCoverage::Render.from_json(config, paths)
    end
  end
end
