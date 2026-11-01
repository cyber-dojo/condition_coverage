require 'json'

module ConditionCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result#operands gives them, to path as
    # {"sites": {site: [counts, ...]}}.
    def self.write(operands, path)
      File.write(path, json(operands))
    end

    # operands as the JSON report's text.
    def self.json(operands)
      JSON.pretty_generate('sites' => operands)
    end
  end
end
