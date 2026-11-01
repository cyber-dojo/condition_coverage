require_relative 'test_helper'
require 'condition_coverage/configuration'

class ConfigurationTest < Id58TestBase
  test 'A9MJ10', %w(
  | a misspelt setting in the start block is refused,
  | naming it and listing the settings there are,
  | rather than failing with a NoMethodError
  ) do
    error = assert_raises(ConditionCoverage::ConfigurationError) do
      ConditionCoverage::Configuration.new do
        root '/app'
        covr 'source/**/*.rb'
      end
    end
    expected = [
      'unknown setting covr in ConditionCoverage.start',
      'the settings are: collector, cover, coverage_dir, report, root'
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'A9MJ15', %w(
  | an unknown reporter in the start block is refused,
  | naming it and listing the reporters there are
  ) do
    error = assert_raises(ConditionCoverage::ConfigurationError) do
      ConditionCoverage::Configuration.new do
        root '/app'
        report :gaps, :htm
      end
    end
    expected = [
      'unknown reporter htm in ConditionCoverage.start',
      'the reporters are: gaps, html, post'
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'A9MJ20', %w(
  | a configuration does not claim to respond to a setting
  | that does not exist
  ) do
    config = ConditionCoverage::Configuration.new { root '/app' }
    refute config.respond_to?(:covr)
  end
end
