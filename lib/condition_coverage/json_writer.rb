require 'json'

module ConditionCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result#operands gives them, to path as
    # {"sites": {site: [counts, ...]}}.
    def self.write(operands, path)
      json = JSON.pretty_generate('sites' => operands)
      File.write(path, json)
    end
  end
end
