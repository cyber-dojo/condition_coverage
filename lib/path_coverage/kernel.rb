require 'fileutils'
require_relative 'configuration'
require_relative 'json_writer'
require_relative 'manifest'
require_relative 'path_gaps'
require_relative 'path_manifest'
require_relative 'paths_report'
require_relative 'recorder'
require_relative 'render'
require_relative 'result'
require_relative 'rewriter'

# Path coverage for Ruby. This file is the kernel: it loads
# before any covered file and is never itself instrumented, since
# an instrumented recorder would record itself.
module PathCoverage
  @recorder = Recorder.new
  @config = nil
  # { full path => {source:, sites:} } of each covered file
  # parsed as it loaded, so the exit report need not read it
  # again.
  @parsed = {}

  # The one recorder that every instrumented operand reports to.
  def self.recorder
    @recorder
  end

  # The configuration of the latest start, which the load
  # hook consults; nil before the first start.
  def self.config
    @config
  end

  # The call rewritten code makes around each operand; returns
  # value unchanged.
  def self.record(site, index, value)
    @recorder.record(site, index, value)
  end

  # The call rewritten code makes before a site's first leaf,
  # site having size leaves; returns the evaluation's trail.
  def self.enter(site, size)
    @recorder.enter(site, size)
  end

  # The call rewritten code makes around a site as a whole,
  # with the trail enter gave it; returns value unchanged.
  def self.leave(trail, value)
    @recorder.leave(trail, value)
  end

  # The call rewritten code makes as a call reaches its
  # method's first decision; returns the call's new path.
  def self.path(site, size)
    @recorder.path(site, size)
  end

  # The call rewritten code makes around each decision's
  # predicate, with exits for one whose arm leaves the method;
  # returns value unchanged.
  def self.decide(path, index, value, exits = nil)
    @recorder.decide(path, index, value, exits)
  end

  # Instruments every file later required that the settings
  # block covers, and reports when the process exits. on_exit
  # is Kernel#at_exit except in tests, which must not print
  # a report as their own process exits.
  def self.start(on_exit: method(:at_exit), &)
    config = Configuration.new(&)
    install_hook if @config.nil?
    @config = config
    on_exit.call { report(config) }
  end

  # Starts from settings in env alone, for a run whose code
  # cannot be changed, eg one started by RUBYOPT=-r: covers
  # the comma-separated PATH_COVERAGE_COVER globs under
  # PATH_COVERAGE_ROOT, writing the JSON report into
  # PATH_COVERAGE_DIR and POSTing it to
  # PATH_COVERAGE_COLLECTOR. Without a collector it
  # starts nothing, so RUBYOPT can be set for every run.
  def self.start_from_env(env, on_exit: method(:at_exit))
    return unless env.key?('PATH_COVERAGE_COLLECTOR')

    start(on_exit:) do
      root env.fetch('PATH_COVERAGE_ROOT')
      env.fetch('PATH_COVERAGE_COVER').split(',').each do |glob|
        cover glob
      end
      coverage_dir env.fetch('PATH_COVERAGE_DIR')
      collector env.fetch('PATH_COVERAGE_COLLECTOR')
      report :post
    end
  end

  # Routes every later load through instrumented, under
  # whichever configuration is current. Installed once: a
  # second definition would warn that it was redefined.
  def self.install_hook
    iseq = RubyVM::InstructionSequence
    iseq.singleton_class.define_method(:load_iseq) do |path|
      PathCoverage.instrumented(path, PathCoverage.config)
    end
  end

  # The compiled, rewritten code of path, or nil for a path
  # config does not cover, which Ruby then loads as normal.
  def self.instrumented(path, config)
    return unless config.covers?(path)

    parsed = @parsed[path] = Manifest.parse(path, config)
    methods = path_methods(path, parsed[:source], config)
    sites = parsed[:sites]
    rewritten = Rewriter.rewrite(parsed[:source], sites, methods)
    RubyVM::InstructionSequence.compile(rewritten, path, path)
  end

  # The methods of the covered file at path whose paths are
  # counted, none unless config measures paths.
  def self.path_methods(path, source, config)
    return {} unless config.measures.include?(:paths)

    PathManifest.methods(source, config.relative(path))
  end

  # Writes the JSON report, then runs the chosen reporters, for
  # every covered file whether or not the run loaded it, into
  # coverage_dir, created first if need be. The paths never
  # taken follow the condition gaps.
  def self.report(config)
    files = parsed_files(config)
    result = collect(files, config)
    paths = config.measures.include?(:paths) ? @recorder.paths : nil
    Render.run(
      result.operands, files, config, paths, site_paths: result.paths
    )
    return unless config.reporters.include?(:gaps)

    methods = path_methods_of(files, config)
    PathGaps.lines(methods, @recorder.paths).each { |line| puts line }
  end

  # The methods whose paths are counted of every covered file,
  # in one manifest.
  def self.path_methods_of(files, config)
    all = files.map do |path, parsed|
      path_methods(path, parsed[:source], config)
    end
    all.reduce({}, :merge)
  end

  # The Result of every covered file, with the counts and site
  # paths this run recorded, once its operands and paths are
  # written as the JSON report.
  def self.collect(files, config)
    sites = merged_sites(files)
    result = Result.new(sites, @recorder.counts, @recorder.site_paths)
    FileUtils.mkdir_p(config.output_dir)
    report = PathsReport.of(result.paths, files)
    JsonWriter.write(result.operands, config.json_path, report)
    result
  end

  # { full path => {source:, sites:} } for every covered file:
  # as parsed when it loaded, or parsed now for a file the run
  # never loaded.
  def self.parsed_files(config)
    config.files.to_h do |path|
      [path, @parsed.fetch(path) { Manifest.parse(path, config) }]
    end
  end

  # The sites of every covered file, in one manifest.
  def self.merged_sites(files)
    files.values.map { |parsed| parsed[:sites] }.reduce({}, :merge)
  end
end
