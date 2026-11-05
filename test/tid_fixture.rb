require 'fileutils'
require 'json'
require 'tmpdir'

# The t a TidTest's body is given: its tid and description, and
# a dir named for its tid, so no two tests' fixtures meet, removed
# once the test ends; source files in it; path_coverage started
# over it, its reports written into it.
class TidFixture
  # A fixture for the test whose tid is id and whose description
  # is description; its dir is made only when first asked for.
  def initialize(id, description)
    @id = id
    @description = description
    @dir = nil
    @report = nil
  end

  attr_reader :id, :description

  # The test's own dir, its name holding the tid, made as it is
  # first asked for.
  def dir
    @dir ||= Dir.mktmpdir(id)
  end

  # Removes the test's dir, when one was made.
  def remove
    FileUtils.remove_entry(@dir) if @dir
  end

  # The name of the test's one source file, for a test that needs
  # no more; the test's dir is its own, so no name need hold the
  # tid.
  def file
    'fixture.rb'
  end

  # Writes source as the file name, in the test's dir, any folders
  # it is in made first.
  def write(source, name = file)
    full = path(name)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, source)
  end

  # Example: a file defining module Fee gives a module holding Fee.
  # Loads the file name wrapped in a module of its own, which it
  # returns, so the file's constants never meet another test's.
  def load(name = file)
    wrap = Module.new
    Kernel.load(path(name), wrap)
    wrap
  end

  # Starts path_coverage covering the .rb files in the test's dir
  # and reporting into it, with any more settings in settings, as
  # a coverage block names them; report runs its exit report.
  def start(&settings)
    require 'path_coverage'
    home = dir
    on_exit = ->(&block) { @report = block }
    PathCoverage.start(on_exit:) do
      root home
      cover '*.rb'
      coverage_dir home
      instance_eval(&settings) if settings
    end
  end

  # Runs the exit report of the run start began, as the process's
  # exit would.
  def report
    @report.call
  end

  # The JSON report the run wrote into the test's dir.
  def json
    JSON.parse(File.read("#{dir}/path_coverage.json"))
  end

  private

  # The full path of the file name in the test's dir.
  def path(name)
    "#{dir}/#{name}"
  end
end
