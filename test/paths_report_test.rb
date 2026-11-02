require_relative 'test_helper'
require 'condition_coverage/paths_report'

class PathsReportTest < Id58TestBase
  test 'Pr7q10', %w(
  | the paths report gives each site its leaves' spans, as
  | line:column pairs, beside each path and its count, so a
  | tool reading the JSON can recover each leaf exactly
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end
    RUBY
    site = condition('&&', 16...23, 27...35)
    sites = { 'k.rb:2:2' => site }
    files = { '/app/k.rb' => { source:, sites: } }
    taken = [
      { path: [true, true], count: 1 },
      { path: [true, false], count: 0 },
      { path: [false, nil], count: 2 }
    ]
    expected = {
      'k.rb:2:2' => {
        leaves: [%w(2:2 2:9), %w(2:13 2:21)], taken:
      }
    }
    report = ConditionCoverage::PathsReport
    assert_equal expected, report.of({ 'k.rb:2:2' => taken }, files)
  end

  test 'Pr7q20', %w(
  | each site's leaf texts are cut from its file's source,
  | for the gap lines to name
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end
    RUBY
    site = condition('&&', 16...23, 27...35)
    sites = { 'k.rb:2:2' => site }
    files = { '/app/k.rb' => { source:, sites: } }
    expected = { 'k.rb:2:2' => ['ok?(id)', 'new?(id)'] }
    assert_equal expected, ConditionCoverage::PathsReport.texts(files)
  end
end
