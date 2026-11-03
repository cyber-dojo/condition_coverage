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

  # The line and branch totals of one group's files, each with
  # where it was missed, so a run missing a line only now and
  # then names it in the run that missed it.
  def group_totals(files)
    branches = missed_branches_of(files)
    {
      lines: metric(files.lines_of_code, missed_lines_of(files)),
      branches: metric(files.total_branches, branches)
    }
  end

  # One metric's total, its missed count, and where each was
  # missed.
  def metric(total, where)
    { total:, missed: where.size, where: }
  end

  # Each line missed in files, eg "lib/path_coverage/x.rb:17".
  def missed_lines_of(files)
    files.flat_map do |file|
      file.missed_lines.map do |line|
        "#{name_of(file)}:#{line.line_number}"
      end
    end
  end

  # Each branch missed in files, eg "lib/path_coverage/x.rb:54 then".
  def missed_branches_of(files)
    files.flat_map do |file|
      file.missed_branches.map do |branch|
        "#{name_of(file)}:#{branch.start_line} #{branch.type}"
      end
    end
  end

  # file's path relative to the project root.
  def name_of(file)
    file.project_filename.delete_prefix('/')
  end

  # Where the metrics land, beside SimpleCov's own report.
  def output_path
    File.join(SimpleCov.coverage_path, 'coverage_metrics.json')
  end
end
