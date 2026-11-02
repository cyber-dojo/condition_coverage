require 'json'

module ConditionCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands and outcomes, as Result gives them, to
    # path as {"sites": {site: [counts, ...]}, "outcomes":
    # {site: counts}}.
    def self.write(operands, path, outcomes = {})
      File.write(path, json(operands, outcomes))
    end

    # operands, and any outcomes, as the JSON report's text.
    def self.json(operands, outcomes = {})
      report = { 'sites' => operands }
      report['outcomes'] = outcomes unless outcomes.empty?
      JSON.pretty_generate(report)
    end
  end
end
