require_relative 'test_helper'
require 'path_coverage/configuration'

class ConfigurationTest < Id58TestBase
  test 'A9MJ10', %w(
  | a misspelt setting in the start block is refused,
  | naming it and listing the settings there are,
  | rather than failing with a NoMethodError
  ) do
    error = assert_raises(PathCoverage::ConfigurationError) do
      PathCoverage::Configuration.new do
        root '/app'
        covr 'source/**/*.rb'
      end
    end
    expected = [
      'unknown setting covr in PathCoverage.start',
      'the settings are: ' \
      'collector, cover, coverage_dir, group, measure, report, ' \
      'root, skip'
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'A9MJ50', %w(
  | Example: group 'Models', 'source/models/**/*.rb'
  | and group 'Routes', 'source/app/routes_*.rb', 'source/api/*.rb'
  | groups names each group's globs, in the order given.
  | With no group setting there are none.
  ) do
    config = PathCoverage::Configuration.new do
      root '/app'
      group 'Models', 'source/models/**/*.rb'
      group 'Routes', 'source/app/routes_*.rb', 'source/api/*.rb'
    end
    expected = {
      'Models' => ['source/models/**/*.rb'],
      'Routes' => ['source/app/routes_*.rb', 'source/api/*.rb']
    }
    assert_equal expected, config.groups
    plain = PathCoverage::Configuration.new { root '/app' }
    assert_equal({}, plain.groups)
  end

  test 'A9MJ40', %w(
  | Example: cover 'source/**/*.rb', skip 'source/vendor/**/*.rb'
  | A file a skip glob matches is not covered, though a cover
  | glob matches it too.
  | So it is neither among the files reported nor instrumented.
  | Every other covered file still is.
  ) do
    dir = Dir.mktmpdir('A9MJ40')
    FileUtils.mkdir_p("#{dir}/source/vendor")
    File.write("#{dir}/source/kata.rb", "ok = 1\n")
    File.write("#{dir}/source/vendor/zip.rb", "ok = 2\n")
    config = PathCoverage::Configuration.new do
      root dir
      cover 'source/**/*.rb'
      skip 'source/vendor/**/*.rb'
    end
    assert_equal ["#{dir}/source/kata.rb"], config.files
    covered = %w(kata.rb vendor/zip.rb).map do |name|
      config.covers?("#{dir}/source/#{name}")
    end
    assert_equal [true, false], covered
  end

  test 'A9MJ60', %w(
  | Example: cover 'source/**/*.rb', skip 'source/**'
  | With no files under source, there are no files.
  | With kata.rb, it is skipped, so there are none.
  | With kata.rb and team.rb, both are skipped, so there are none.
  ) do
    actual = [[], %w(kata.rb), %w(kata.rb team.rb)].map do |names|
      dir = Dir.mktmpdir('A9MJ60')
      FileUtils.mkdir_p("#{dir}/source")
      names.each do |name|
        File.write("#{dir}/source/#{name}", "ok = 1\n")
      end
      config = PathCoverage::Configuration.new do
        root dir
        cover 'source/**/*.rb'
        skip 'source/**'
      end
      config.files
    end
    assert_equal [[], [], []], actual
  end

  test 'A9MJ70', %w(
  | Example: no cover, cover 'source/*.rb', and cover 'lib/*.rb'
  | with cover 'source/*.rb'
  | With no cover glob, no file is covered.
  | source/kata.rb is covered when any glob matches it.
  | test/kata_test.rb is covered by none of them.
  ) do
    covers = [[], %w(source/*.rb), %w(lib/*.rb source/*.rb)]
    configs = covers.map do |globs|
      PathCoverage::Configuration.new do
        root '/app'
        globs.each { |glob| cover glob }
      end
    end
    actual = configs.map do |config|
      %w(source/kata.rb test/kata_test.rb).map do |path|
        config.covers?("/app/#{path}")
      end
    end
    expected = [[false, false], [true, false], [true, false]]
    assert_equal expected, actual
  end

  test 'A9MJ15', %w(
  | an unknown reporter in the start block is refused,
  | naming it and listing the reporters there are
  ) do
    error = assert_raises(PathCoverage::ConfigurationError) do
      PathCoverage::Configuration.new do
        root '/app'
        report :gaps, :htm
      end
    end
    expected = [
      'unknown reporter htm in PathCoverage.start',
      'the reporters are: gaps, html, post, summary'
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'A9MJ20', %w(
  | a configuration does not claim to respond to a setting
  | that does not exist
  ) do
    config = PathCoverage::Configuration.new { root '/app' }
    refute config.respond_to?(:covr)
  end

  test 'A9MJ30', %w(
  | Example: a start block with no measure
  | Paths within each decision are measured.
  | Example: measure :decisions, :methods
  | Paths within each method are measured too.
  ) do
    config = PathCoverage::Configuration.new { root '/app' }
    assert_equal [:decisions], config.measures
    config = PathCoverage::Configuration.new do
      root '/app'
      measure :decisions, :methods
    end
    assert_equal %i[decisions methods], config.measures
  end

  test 'A9MJ31', %w(
  | an unknown measure in the start block is refused,
  | naming it and listing the measures there are
  ) do
    error = assert_raises(PathCoverage::ConfigurationError) do
      PathCoverage::Configuration.new do
        root '/app'
        measure :decisions, :method
      end
    end
    expected = [
      'unknown measure method in PathCoverage.start',
      'the measures are: decisions, methods'
    ].join("\n")
    assert_equal expected, error.message
  end
end
