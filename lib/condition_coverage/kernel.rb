require 'fileutils'
require_relative 'configuration'
require_relative 'json_writer'
require_relative 'manifest'
require_relative 'recorder'
require_relative 'render'
require_relative 'result'
require_relative 'rewriter'

# Condition coverage for Ruby. This file is the kernel: it loads
# before any covered file and is never itself instrumented, since
# an instrumented recorder would record itself.
module ConditionCoverage
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
  # the comma-separated CONDITION_COVERAGE_COVER globs under
  # CONDITION_COVERAGE_ROOT, writing the JSON report into
  # CONDITION_COVERAGE_DIR and POSTing it to
  # CONDITION_COVERAGE_COLLECTOR. Without a collector it
  # starts nothing, so RUBYOPT can be set for every run.
  def self.start_from_env(env, on_exit: method(:at_exit))
    return unless env.key?('CONDITION_COVERAGE_COLLECTOR')

    start(on_exit:) do
      root env.fetch('CONDITION_COVERAGE_ROOT')
      env.fetch('CONDITION_COVERAGE_COVER').split(',').each do |glob|
        cover glob
      end
      coverage_dir env.fetch('CONDITION_COVERAGE_DIR')
      collector env.fetch('CONDITION_COVERAGE_COLLECTOR')
      report :post
    end
  end

  # Routes every later load through instrumented, under
  # whichever configuration is current. Installed once: a
  # second definition would warn that it was redefined.
  def self.install_hook
    iseq = RubyVM::InstructionSequence
    iseq.singleton_class.define_method(:load_iseq) do |path|
      ConditionCoverage.instrumented(path, ConditionCoverage.config)
    end
  end

  # The compiled, rewritten code of path, or nil for a path
  # config does not cover, which Ruby then loads as normal.
  def self.instrumented(path, config)
    return unless config.covers?(path)

    parsed = @parsed[path] = Manifest.parse(path, config)
    rewritten = Rewriter.rewrite(parsed[:source], parsed[:sites])
    RubyVM::InstructionSequence.compile(rewritten, path, path)
  end

  # Writes the JSON report, then runs the chosen reporters, for
  # every covered file whether or not the run loaded it, into
  # coverage_dir, created first if need be.
  def self.report(config)
    files = parsed_files(config)
    operands = collect(files, config)
    Render.run(operands, files, config)
  end

  # The operands of every covered file, with the counts this
  # run recorded, once written as the JSON report.
  def self.collect(files, config)
    sites = merged_sites(files)
    operands = Result.new(sites, @recorder.counts).operands
    FileUtils.mkdir_p(config.output_dir)
    JsonWriter.write(operands, config.json_path)
    operands
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
