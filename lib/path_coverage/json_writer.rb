require 'json'

module PathCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result gives them, paths, as
    # PathsReport gives them, and totals, as Kernel.totals gives
    # them, to path as {"sites": {site: [counts, ...]}, "paths":
    # {site: {leaves:, taken:}}, "totals": {"decisions": [taken,
    # possible]}}.
    def self.write(operands, path, paths = {}, totals: {})
      File.write(path, json(operands, paths, totals:))
    end

    # operands, and any paths and totals, as the JSON report's
    # text.
    def self.json(operands, paths = {}, totals: {})
      report = { 'sites' => operands }
      report['paths'] = paths unless paths.empty?
      report['totals'] = totals unless totals.empty?
      JSON.pretty_generate(report)
    end
  end
end
