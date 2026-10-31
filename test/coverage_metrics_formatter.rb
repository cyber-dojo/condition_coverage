require 'simplecov'
require 'json'

# A SimpleCov formatter writing coverage_metrics.json: per-group
# line and branch totals, which bin/check_coverage_metrics.rb
# judges against test/coverage_metrics_params.json.
#
# based on https://github.com/vicentllongo/simplecov-json
class CoverageMetricsFormatter
  # Writes the per-group totals and returns them as JSON.
  def format(result)
    data = result.groups.to_h do |name, files|
      [name, group_totals(files)]
    end
    File.write(output_path, JSON.pretty_generate(data))
    data.to_json
  end

  private

  # The line and branch totals of one group's files.
  def group_totals(files)
    {
      lines: {
        total: files.lines_of_code,
        missed: files.missed_lines
      },
      branches: {
        total: files.total_branches,
        missed: files.missed_branches
      }
    }
  end

  # Where the metrics land, beside SimpleCov's own report.
  def output_path
    File.join(SimpleCov.coverage_path, 'coverage_metrics.json')
  end
end
