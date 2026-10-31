require 'json'

module ConditionCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes result to path as {"sites": {site: [counts, ...]}}.
    def self.write(result, path)
      json = JSON.pretty_generate('sites' => result.operands)
      File.write(path, json)
    end
  end
end
