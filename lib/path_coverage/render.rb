require 'json'
require_relative 'gaps'
require_relative 'html_report'
require_relative 'manifest'
require_relative 'merge'
require_relative 'paths_report'
require_relative 'post'
require_relative 'site_paths'

module PathCoverage
  # The reporters, run from operands alone: needing nothing the
  # run recorded beyond them, they can run in another process.
  module Render
    # Runs each reporter chosen in config. operands and
    # site_paths are as Result gives them; files is { full path
    # => {source:, sites:} } for each covered file.
    def self.run(operands, files, config, paths = nil, site_paths: {})
      site_paths = every_site(site_paths, files)
      reporters = config.reporters
      gaps(operands, files, site_paths) if reporters.include?(:gaps)
      if reporters.include?(:html)
        HtmlReport.write(operands, files, config, paths, site_paths:)
      end
      return unless reporters.include?(:post)

      report = PathsReport.of(site_paths, files)
      Post.deliver(operands, config.collector_url, report)
    end

    # site_paths with every site in files that it lacks, eg
    # from a JSON report with no paths, given each possible
    # path at a count of zero: unable to say which paths such
    # a site took, the report claims none.
    def self.every_site(site_paths, files)
      none = files.values.each_with_object({}) do |parsed, all|
        parsed[:sites].each do |site, condition|
          all[site] = SitePaths.possible(condition).map do |path|
            { path:, count: 0 }
          end
        end
      end
      none.merge(site_paths)
    end

    # Prints the gap lines: each path a site never took, each
    # leaf named by its text in files.
    def self.gaps(operands, files, site_paths)
      texts = PathsReport.texts(files)
      lines = Gaps.lines(operands, paths: site_paths, texts:)
      lines.each { |line| puts line }
    end

    # Runs the reporters chosen in config from the JSON reports
    # at paths, their counts merged, parsing each covered file
    # afresh. paths is config.json_path alone by default.
    def self.from_json(config, paths = [config.json_path])
      operands = Merge.operands(paths.map { |path| read(path) })
      site_paths = Merge.paths(paths.map { |path| paths_of(path) })
      files = config.files.to_h do |path|
        [path, Manifest.parse(path, config)]
      end
      run(operands, files, config, site_paths:)
    end

    # The site paths of the JSON report at path, as
    # Result#paths gives them; none for a report that has none.
    def self.paths_of(path)
      json = JSON.parse(File.read(path))
      json.fetch('paths', {}).transform_values do |site|
        site['taken'].map do |each|
          { path: each['path'], count: each['count'] }
        end
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
