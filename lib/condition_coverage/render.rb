require 'json'
require_relative 'gaps'
require_relative 'html_report'
require_relative 'manifest'

module ConditionCoverage
  # The reporters, run from operands alone: needing nothing the
  # run recorded beyond them, they can run in another process.
  module Render
    # Runs each reporter chosen in config. operands are as
    # Result#operands gives them; files is { full path =>
    # {source:, sites:} } for each covered file.
    def self.run(operands, files, config)
      reporters = config.reporters
      if reporters.include?(:gaps)
        Gaps.lines(operands).each { |line| puts line }
      end
      return unless reporters.include?(:html)

      HtmlReport.write(operands, files, config)
    end

    # Runs the reporters chosen in config from the JSON report
    # at config.json_path, parsing each covered file afresh.
    def self.from_json(config)
      json = JSON.parse(File.read(config.json_path))
      operands = json['sites'].transform_values do |leaves|
        leaves.map { |leaf| counts(leaf) }
      end
      files = config.files.to_h do |path|
        [path, Manifest.parse(path, config)]
      end
      run(operands, files, config)
    end

    # One operand's counts as JSON holds them, with the keys,
    # and any only: value, as the symbols Result#operands uses.
    def self.counts(leaf)
      counts = { truthy: leaf['truthy'], falsy: leaf['falsy'] }
      only = leaf['only']
      only ? counts.merge(only: only.to_sym) : counts
    end
  end
end
