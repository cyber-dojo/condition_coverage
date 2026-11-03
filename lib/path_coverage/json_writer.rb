require 'json'

module PathCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result gives them, paths, as
    # PathsReport gives them, totals, as Kernel.totals gives
    # them, and method_paths, as the recorder counts them, to
    # path as {"sites": {site: [counts, ...]}, "paths":
    # {site: {leaves:, taken:}}, "method_paths": {site:
    # [{path:, count:}, ...]}, "totals": {"decisions": [taken,
    # possible]}}.
    def self.write(operands, path, paths = {}, totals: {},
                   method_paths: {})
      File.write(path, json(operands, paths, totals:, method_paths:))
    end

    # operands, and any paths, method paths and totals, as the
    # JSON report's text.
    def self.json(operands, paths = {}, totals: {}, method_paths: {})
      report = { 'sites' => operands }
      report['paths'] = paths unless paths.empty?
      unless method_paths.empty?
        report['method_paths'] = listed(method_paths)
      end
      report['totals'] = totals unless totals.empty?
      JSON.pretty_generate(report)
    end

    # method_paths, { site => { path => count } }, as JSON lists
    # them, eg { 'k.rb:2:2' => [{ path: [true, false], count: 1 }] }.
    def self.listed(method_paths)
      method_paths.transform_values do |taken|
        taken.map { |path, count| { path:, count: } }
      end
    end
  end
end
