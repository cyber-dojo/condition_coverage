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
      'collector, cover, coverage_dir, measure, report, root'
    ].join("\n")
    assert_equal expected, error.message
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
      'the reporters are: gaps, html, post'
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
  | Paths across each method's decisions are measured too.
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
