require 'json'

module ConditionCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result gives them, and paths, as
    # PathsReport gives them, to path as {"sites": {site:
    # [counts, ...]}, "paths": {site: {leaves:, taken:}}}.
    def self.write(operands, path, paths = {})
      File.write(path, json(operands, paths))
    end

    # operands, and any paths, as the JSON report's text.
    def self.json(operands, paths = {})
      report = { 'sites' => operands }
      report['paths'] = paths unless paths.empty?
      JSON.pretty_generate(report)
    end
  end
end
