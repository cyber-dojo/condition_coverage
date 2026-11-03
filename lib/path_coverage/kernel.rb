require 'fileutils'
require_relative 'calls'
require_relative 'configuration'
require_relative 'console_summary'
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
  # PATH_COVERAGE_ROOT, skipping any matching the
  # comma-separated PATH_COVERAGE_SKIP globs, writing the JSON
  # report into PATH_COVERAGE_DIR and POSTing it to
  # PATH_COVERAGE_COLLECTOR. Without a collector it
  # starts nothing, so RUBYOPT can be set for every run.
  def self.start_from_env(env, on_exit: method(:at_exit))
    return unless env.key?('PATH_COVERAGE_COLLECTOR')

    start(on_exit:, &env_settings(env))
  end

  # The start block of the settings in env, as start_from_env
  # reads them.
  def self.env_settings(env)
    covers = env.fetch('PATH_COVERAGE_COVER').split(',')
    skips = env.fetch('PATH_COVERAGE_SKIP', '').split(',')
    proc do
      root env.fetch('PATH_COVERAGE_ROOT')
      covers.each { |glob| cover glob }
      skips.each { |glob| skip glob }
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
  # counted, none unless config measures methods.
  def self.path_methods(path, source, config)
    return {} unless config.measures.include?(:methods)

    PathManifest.methods(source, config.relative(path))
  end

  # Writes the JSON report, then runs the chosen reporters, for
  # every covered file whether or not the run loaded it, into
  # coverage_dir, created first if need be. The paths never
  # taken follow the condition gaps.
  def self.report(config)
    files = parsed_files(config)
    result = collect(files, config)
    methods = config.measures.include?(:methods)
    paths = methods ? @recorder.paths : nil
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
    write_json(result, files, config)
    result
  end

  # Writes result as the JSON report at config's json_path: its
  # operands, site paths and totals, and the method paths the
  # recorder counted, so a render from the JSON alone has them.
  def self.write_json(result, files, config)
    report = PathsReport.of(result.paths, files)
    totals = totals(result, files, config)
    JsonWriter.write(result.operands, config.json_path, report,
                     totals:, method_paths: @recorder.paths)
  end

  # The JSON report's totals, each [taken, possible] paths:
  # within each decision, and, when config measures methods,
  # within each method too; with groups configured, each group's
  # own too, under groups.
  def self.totals(result, files, config)
    measured = config.measures.include?(:methods)
    methods = measured ? path_methods_of(files, config) : {}
    paths = measured ? @recorder.paths : nil
    totals = ConsoleSummary.totals(result.paths, methods, paths)
    groups = config.groups
    return totals if groups.empty?

    summary = ConsoleSummary
    own = summary.group_totals(result.paths, methods, paths, groups)
    totals.merge('groups' => own)
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
