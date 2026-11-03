require_relative 'test_helper'
require 'path_coverage/configuration'
require 'path_coverage/json_writer'
require 'path_coverage/manifest'
require 'path_coverage/render'
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
    sites = PathCoverage::Manifest.sites(source, 'kata.rb')
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
      writer = PathCoverage::JsonWriter
      writer.write({ site => operands }, file, report)
      file
    end
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    gap = "#{site} path never taken: " \
          '`ok?(id)` true, `id.size == 6` true'
    assert_output("#{gap}\n", '') do
      PathCoverage::Render.from_json(config, paths)
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
    sites = PathCoverage::Manifest.sites(source, 'kata.rb')
    site = sites.keys.first
    operands = [{ truthy: 1, falsy: 1 }, { truthy: 1, falsy: 0 }]
    file = "#{dir}/run.json"
    PathCoverage::JsonWriter.write({ site => operands }, file)
    config = PathCoverage::Configuration.new do
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
      PathCoverage::Render.from_json(config, [file])
    end
  end

  test 'Rn5d30', %w(
  | a JSON report from a run that measured other kinds, eg
  | one with writes switched off, lists its sites' paths
  | differently, so rendering from it is refused rather than
  | crediting one path's count to another
  ) do
    dir = Dir.mktmpdir('Rn5d30')
    source = "def kata?(id) = ok?(id) && id.size == 6\n"
    File.write("#{dir}/kata.rb", source)
    sites = PathCoverage::Manifest.sites(source, 'kata.rb')
    site = sites.keys.first
    operands = [{ truthy: 1, falsy: 1 }, { truthy: 1, falsy: 0 }]
    file = "#{dir}/run.json"
    PathCoverage::JsonWriter.write({ site => operands }, file)
    json = JSON.parse(File.read(file))
    json['kinds'] -= ['write']
    File.write(file, JSON.generate(json))
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    error = assert_raises(ArgumentError) do
      PathCoverage::Render.from_json(config, [file])
    end
    assert_equal "#{file} measured other kinds", error.message
  end

  test 'Rn5d31', %w(
  | Example: a JSON report from a run with ignore '&&', rendered
  | with nothing ignored
  | The render would list the && site's paths, which the run
  | never measured, so rendering from it is refused.
  ) do
    dir = Dir.mktmpdir('Rn5d31')
    source = "def kata?(id) = ok?(id) && id.size == 6\n"
    File.write("#{dir}/kata.rb", source)
    file = "#{dir}/run.json"
    fingerprint = { 'ignored' => ['&&'] }
    PathCoverage::JsonWriter.write({}, file, fingerprint:)
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    error = assert_raises(ArgumentError) do
      PathCoverage::Render.from_json(config, [file])
    end
    assert_equal "#{file} measured other kinds", error.message
  end

  test 'Rn5d32', %w(
  | Example: report :summary with ignore '&&=', '||='
  | The summary names the operators ignored after its totals,
  | so a total that leaves out their sites never passes for
  | one that measured them.
  ) do
    dir = Dir.mktmpdir('Rn5d32')
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :summary
      ignore '&&=', '||='
    end
    expected = [
      'Path coverage within decisions: 0 / 0 (-)',
      'Path coverage ignores: &&=, ||='
    ].join("\n")
    assert_output("#{expected}\n", '') do
      PathCoverage::Render.run({}, {}, config)
    end
  end

  test 'Rn5d33', %w(
  | Example: a JSON report from a run with treat 'name', as:
  | :present, rendered with no treat
  | The run listed no nil path for a name&. receiver, the render
  | would, so rendering from it is refused.
  ) do
    dir = Dir.mktmpdir('Rn5d33')
    File.write("#{dir}/size.rb", "def size(u) = u.name&.size\n")
    file = "#{dir}/run.json"
    fingerprint = { 'treats' => [['name', 'present', nil]] }
    PathCoverage::JsonWriter.write({}, file, fingerprint:)
    config = PathCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      report :gaps
    end
    error = assert_raises(ArgumentError) do
      PathCoverage::Render.from_json(config, [file])
    end
    assert_equal "#{file} measured other kinds", error.message
  end
end
