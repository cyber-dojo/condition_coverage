require_relative 'console_summary'
require_relative 'gaps'
require_relative 'html_report'
require_relative 'json_reader'
require_relative 'manifest'
require_relative 'paths_report'
require_relative 'post'
require_relative 'site_paths'

module PathCoverage
  # The reporters, run from operands alone: needing nothing the
  # run recorded beyond them, they can run in another process.
  module Render
    # Runs each reporter chosen in config. operands, and taken's
    # site_paths: and outside:, are as Result gives them; files
    # is { full path => {source:, sites:} } for each covered file.
    def self.run(operands, files, config, paths = nil, **taken)
      site_paths = every_site(taken.fetch(:site_paths, {}), files)
      reporters = config.reporters
      if reporters.include?(:gaps)
        gaps(operands, files, site_paths, taken.fetch(:outside, {}))
      end
      html_and_summary(operands, files, config, [paths, site_paths])
      return unless reporters.include?(:post)

      post(operands, files, config, site_paths)
    end

    # Runs the :post reporter: operands, and the paths report of
    # site_paths in files, with config's fingerprint.
    def self.post(operands, files, config, site_paths)
      report = PathsReport.of(site_paths, files)
      url = config.collector_url
      fingerprint = config.fingerprint
      Post.deliver(operands, url, report, fingerprint:)
    end

    # Runs the :html and :summary reporters, each when chosen.
    def self.html_and_summary(operands, files, config, paths_pair)
      paths, site_paths = paths_pair
      reporters = config.reporters
      if reporters.include?(:html)
        HtmlReport.write(operands, files, config, paths, site_paths:)
      end
      return unless reporters.include?(:summary)

      summary(files, config, paths, site_paths)
    end

    # Prints the summary lines: the paths taken of all possible
    # within decisions, and, when paths are given, as they are
    # when methods are measured, within methods; then any
    # operators ignored.
    def self.summary(files, config, paths, site_paths)
      methods = files.map do |full_path, parsed|
        path = config.relative(full_path)
        PathManifest.methods(parsed[:source], path)
      end
      all = methods.reduce({}, :merge)
      groups = config.groups
      puts ConsoleSummary.lines(site_paths, all, paths, groups) +
           ConsoleSummary.ignored_lines(config.ignored)
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

    # Prints the gap lines: each path a site never took, and each
    # path taken that a treatment rules out, as outside lists
    # them, each leaf named by its text in files.
    def self.gaps(operands, files, site_paths, outside)
      texts = PathsReport.texts(files)
      paths = site_paths
      lines = Gaps.lines(operands, paths:, texts:, outside:)
      lines.each { |line| puts line }
    end

    # Runs the reporters chosen in config from the JSON reports
    # at paths, their counts merged, parsing each covered file
    # afresh; with methods measured, the method paths they hold
    # too. paths is config.json_path alone by default.
    def self.from_json(config, paths = [config.json_path])
      operands = JsonReader.operands(paths, config.fingerprint)
      files = config.files.to_h do |path|
        [path, Manifest.parse(path, config)]
      end
      methods = config.measures.include?(:methods)
      taken = methods ? JsonReader.method_paths(paths) : nil
      run(operands, files, config, taken, **JsonReader.taken(paths))
    end
  end
end
