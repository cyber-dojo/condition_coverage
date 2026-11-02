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
  | conditions alone are measured unless measure says
  | otherwise, so a start block written before paths
  | were measured is unchanged by them
  ) do
    config = PathCoverage::Configuration.new { root '/app' }
    assert_equal [:conditions], config.measures
    config = PathCoverage::Configuration.new do
      root '/app'
      measure :conditions, :paths
    end
    assert_equal %i[conditions paths], config.measures
  end

  test 'A9MJ31', %w(
  | an unknown measure in the start block is refused,
  | naming it and listing the measures there are
  ) do
    error = assert_raises(PathCoverage::ConfigurationError) do
      PathCoverage::Configuration.new do
        root '/app'
        measure :conditions, :path
      end
    end
    expected = [
      'unknown measure path in PathCoverage.start',
      'the measures are: conditions, paths'
    ].join("\n")
    assert_equal expected, error.message
  end
end
