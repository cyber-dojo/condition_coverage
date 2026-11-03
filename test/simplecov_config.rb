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
  # SPIKE: the path grids of the HTML report, untested while
  # their design settles.
  skip('lib/path_coverage/html_paths.rb')

  group('code') { |file| file.filename.start_with?('/gem/lib/') }
  group('test') { |file| file.filename.start_with?('/gem/test/') }
end

# The HTML report is silent: bin/check_coverage_metrics.rb prints
# each group's line and branch coverage beside its path coverage,
# so SimpleCov's own totals over every group would only repeat
# them, less usefully.
formatters = [
  SimpleCov::Formatter::HTMLFormatter.new(silent: true),
  CoverageMetricsFormatter
]
SimpleCov.formatters =
  SimpleCov::Formatter::MultiFormatter.new(formatters)
