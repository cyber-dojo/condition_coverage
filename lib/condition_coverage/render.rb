require 'json'
require_relative 'gaps'
require_relative 'html_report'
require_relative 'manifest'
require_relative 'merge'
require_relative 'post'

module ConditionCoverage
  # The reporters, run from operands alone: needing nothing the
  # run recorded beyond them, they can run in another process.
  module Render
    # Runs each reporter chosen in config. operands and
    # outcomes are as Result gives them; files is { full path
    # => {source:, sites:} } for each covered file.
    def self.run(operands, files, config, paths = nil, outcomes: {})
      reporters = config.reporters
      if reporters.include?(:gaps)
        Gaps.lines(operands, outcomes).each { |line| puts line }
      end
      if reporters.include?(:html)
        HtmlReport.write(operands, files, config, paths, outcomes)
      end
      return unless reporters.include?(:post)

      Post.deliver(operands, config.collector_url, outcomes)
    end

    # Runs the reporters chosen in config from the JSON reports
    # at paths, their counts merged, parsing each covered file
    # afresh. paths is config.json_path alone by default.
    def self.from_json(config, paths = [config.json_path])
      operands = Merge.operands(paths.map { |path| read(path) })
      outcomes = Merge.outcomes(paths.map { |p| outcomes_of(p) })
      files = config.files.to_h do |path|
        [path, Manifest.parse(path, config)]
      end
      run(operands, files, config, outcomes:)
    end

    # The site outcomes of the JSON report at path, with the
    # symbol keys Result#outcomes uses; none for a report that
    # has none.
    def self.outcomes_of(path)
      json = JSON.parse(File.read(path))
      json.fetch('outcomes', {}).transform_values do |counts|
        counts.transform_keys(&:to_sym)
      end
    end

    # The operands of the JSON report at path.
    def self.read(path)
      json = JSON.parse(File.read(path))
      json['sites'].transform_values do |leaves|
        leaves.map { |leaf| counts(leaf) }
      end
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
