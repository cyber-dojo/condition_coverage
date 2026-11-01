module ConditionCoverage
  # Raised for a start block that cannot be applied.
  class ConfigurationError < StandardError; end

  # The settings given in a ConditionCoverage.start block.
  class Configuration
    GLOB_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB
    SETTINGS = %w[collector cover coverage_dir report root].freeze
    REPORTERS = %w[gaps html post].freeze

    # Evaluates the settings block against a new configuration.
    def initialize(&)
      @globs = []
      @reporters = [:gaps]
      instance_eval(&)
    end

    # The reporters chosen with report, :gaps when none were.
    attr_reader :reporters

    # The dir the reports are written to.
    def output_dir
      @coverage_dir
    end

    # The url the :post reporter sends the JSON report to.
    attr_reader :collector_url

    # Sets the url the :post reporter sends the JSON report to.
    def collector(url)
      @collector_url = url
    end

    # Sets the dir that cover globs and site names are
    # relative to.
    def root(dir)
      @root = dir
    end

    # Adds a glob, relative to root, of files to instrument.
    def cover(glob)
      @globs << glob
    end

    # Chooses the reporters run at exit, eg report :gaps;
    # refuses a name there is no reporter for.
    def report(*names)
      names.each do |name|
        next if REPORTERS.include?(name.to_s)

        raise ConfigurationError, [
          "unknown reporter #{name} in ConditionCoverage.start",
          "the reporters are: #{REPORTERS.join(', ')}"
        ].join("\n")
      end
      @reporters = names.map(&:to_sym)
    end

    # Sets the dir the condition_coverage.json report is
    # written to.
    def coverage_dir(dir)
      @coverage_dir = dir
    end

    # Every file the cover globs match under root, as full
    # paths, whether or not the run loads it.
    def files
      Dir.glob(@globs, base: @root).sort.map { |f| "#{@root}/#{f}" }
    end

    # Where the JSON report goes.
    def json_path
      "#{output_dir}/condition_coverage.json"
    end

    # True when path is under root and matches a cover glob.
    def covers?(path)
      path.start_with?("#{@root}/") && matches?(relative(path))
    end

    # True when the root-relative path matches a cover glob.
    def matches?(relative_path)
      @globs.any? do |glob|
        File.fnmatch?(glob, relative_path, GLOB_FLAGS)
      end
    end

    # path relative to root, eg "source/kata.rb".
    def relative(path)
      path.delete_prefix("#{@root}/")
    end

    # Refuses a setting that does not exist, naming it.
    def method_missing(name, *)
      raise ConfigurationError, [
        "unknown setting #{name} in ConditionCoverage.start",
        "the settings are: #{SETTINGS.join(', ')}"
      ].join("\n")
    end

    # Answers only for the settings there are.
    def respond_to_missing?(_name, _include_private = false)
      false
    end
  end
end
