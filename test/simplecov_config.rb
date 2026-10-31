require 'simplecov'
require_relative 'coverage_metrics_formatter'

SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
  filters.clear
  root('/gem')
  coverage_dir('/reports')
  cover('lib/**/*.rb')
  cover { |file| file.project_filename.start_with?('test/') }

  group('code') { |file| file.filename.start_with?('/gem/lib/') }
  group('test') { |file| file.filename.start_with?('/gem/test/') }
end

formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  CoverageMetricsFormatter
]
SimpleCov.formatters =
  SimpleCov::Formatter::MultiFormatter.new(formatters)
