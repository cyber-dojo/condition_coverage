require 'English'
require 'etc'
require 'minitest/autorun'
require 'minitest/reporters'

Minitest.parallel_executor =
  Minitest::Parallel::Executor.new(Etc.nprocessors)
Minitest::Reporters.use!(
  [Minitest::Reporters::DefaultReporter.new]
)

# Base class whose tests are named by a unique id58, so
# a run can be narrowed to the ids given on the
# command line.
class Id58TestBase < Minitest::Test
  def initialize(arg)
    @_id58 = nil
    @_name58 = nil
    super
  end

  parallelize_me!

  ARGS = (ARGV.sort.uniq - ['--']).freeze # eg 2m4

  @seen_ids = []
  singleton_class.attr_reader :seen_ids

  # The id58 fragments given on the command line; a
  # subclass can override it.
  def self.args
    ARGS
  end

  # Defines a test only when no ids were given on the
  # command line, or one of them is part of its id58.
  def self.test(id58, *lines, &body)
    id58 = checked_id58(id58, lines)
    return unless selected?(id58)

    name58 = lines.join(' ')
    file = File.basename(body.source_location[0])
    define_method(test_name(id58, name58)) do
      run_id58_test(id58, name58, file, body)
    end
  end

  # True when no ids were given, or one is in id58.
  def self.selected?(id58)
    args.empty? || args.any? { |arg| id58.include?(arg) }
  end

  # The name Minitest reports, id58 and words included.
  def self.test_name(id58, name58)
    :"test_\nid='#{id58}'\n'#{name58}'"
  end

  # Leaves out i I o O, which read too like 1 and 0.
  ID58_ALPHABET = %w(
    0 1 2 3 4 5 6 7 8 9
    A B C D E F G H J K L M N P Q R S T U V W X Y Z
    a b c d e f g h j k l m n p q r s t u v w x y z
  ).join.freeze

  # True when every character of str is in ID58_ALPHABET.
  def self.id58?(str)
    str.is_a?(String) &&
      str.chars.all? { |char| ID58_ALPHABET.include?(char) }
  end

  # Returns id58, or raises naming what is wrong with it.
  def self.checked_id58(id58, lines)
    problem = id58_problem(id58)
    raise id58_error(problem, id58, lines) if problem

    Id58TestBase.seen_ids << id58
    id58
  end

  # Returns why id58 cannot name a test, or nil if it can.
  def self.id58_problem(id58)
    return 'empty' if id58 == ''
    return 'not id58' unless id58?(id58)

    'duplicate' if Id58TestBase.seen_ids.include?(id58)
  end

  # A message with a ! pointing at the offending id58.
  def self.id58_error(problem, id58, lines)
    method = "test '#{id58}',"
    pointer = "#{' ' * method.index("'")}!"
    words = "'#{lines.join(' ')}'"
    parts = ["#{pointer}#{problem}", pointer, method, words]
    "\n\n#{parts.join("\n")}\n\n"
  end

  # Runs body as this test, between the setup and
  # teardown hooks; teardown runs even when body fails.
  def run_id58_test(id58, name58, file, body)
    show_test_id(id58, file)
    @_id58 = id58
    @_name58 = name58
    id58_setup
    begin
      instance_eval(&body)
    ensure
      report_error
      id58_teardown
    end
  end

  # Prints id58 and its file when SHOW_TEST_IDS=true.
  def show_test_id(id58, file)
    return unless ENV['SHOW_TEST_IDS'] == 'true'

    p "#{id58}:#{file}"
  end

  # Prints the message of the error the body raised.
  def report_error
    puts $ERROR_INFO.message unless $ERROR_INFO.nil?
  end

  # Hook for subclasses; runs before each test body.
  def id58_setup; end

  # Hook for subclasses; runs after each test body.
  def id58_teardown; end

  # The running test's id58, eg for naming temp files.
  def id58
    @_id58
  end

  # The running test's description words, joined.
  def name58
    @_name58
  end
end
