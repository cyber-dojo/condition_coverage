require_relative 'test_helper'

class TestHelperTest < Id58TestBase
  # Its tests capture $stdout and set ENV['SHOW_TEST_IDS'].
  serial!

  # The body of a throwaway test that is defined, never run.
  NO_OP = proc { :no_op }

  test 'Fb7A05', %w(
  | a class that calls serial! opts out of parallel running
  | on both counts: it is ordered with the serial suites,
  | and its tests are run in place, not sent to the pool
  ) do
    klass = Class.new(Id58TestBase) { serial! }
    assert_equal :random, klass.run_order
    assert_equal klass.singleton_class, klass.method(:run).owner
  end

  test 'Fb7A10', %w(
  | a running test can read its own id58 and description
  ) do
    assert_equal 'Fb7A10', id58
    words = '| a running test can read its own id58 and description'
    assert_equal words, name58
  end

  test 'Fb7A15', %w(
  | a description written as bar lines keeps those lines,
  | so a report shows it as written
  ) do
    words = %w(
      | POST /kata_create(manifest)
      | has status 200
    )
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax1', words, &NO_OP)
    end
    name = klass.public_instance_methods(false)[0]
    instance = klass.new(name)
    instance.send(name)
    expected = "| POST /kata_create(manifest)\n| has status 200"
    assert_equal expected, instance.name58
  end

  test 'Fb7A17', %w(
  | a || inside a bar line is a word, not two line breaks,
  | so a description can talk about the operator
  ) do
    words = %w(
      | ok? || new? is recorded
      | operand by operand
    )
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax2', words, &NO_OP)
    end
    name = klass.public_instance_methods(false)[0]
    instance = klass.new(name)
    instance.send(name)
    expected = [
      '| ok? || new? is recorded',
      '| operand by operand'
    ].join("\n")
    assert_equal expected, instance.name58
  end

  test 'Fb7A18', %w(
  | the name a failure reports puts every bar line
  | in the same column, so the description reads as written
  ) do
    name58 = "| POST /kata_create(manifest)\n| has status 200"
    expected = [
      'test_',
      "id='Fb7Ax8'",
      '| POST /kata_create(manifest)',
      '| has status 200'
    ].join("\n").to_sym
    actual = Id58TestBase.test_name('Fb7Ax8', name58)
    assert_equal expected, actual
  end

  test 'Fb7A20', %w(
  | an empty id58 is refused, pointing at the offending test
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) { test('', %w(| kata exists), &NO_OP) }
    end
    expected = [
      '',
      '',
      '     !empty',
      '     !',
      "test '',",
      "'| kata exists'",
      '',
      ''
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'Fb7A30', %w(
  | an id58 using a letter outside the alphabet is refused
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) do
        test('Fb7AO1', %w(| kata exists), &NO_OP)
      end
    end
    expected = [
      '',
      '',
      '     !not id58',
      '     !',
      "test 'Fb7AO1',",
      "'| kata exists'",
      '',
      ''
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'Fb7A35', %w(
  | a description not written as bar lines is refused,
  | so every failure report shows its lines as written
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) do
        test('Fb7Ax3', %w(kata exists), &NO_OP)
      end
    end
    expected = [
      '',
      '',
      '     !description lines must start with |',
      '     !',
      "test 'Fb7Ax3',",
      "'kata exists'",
      '',
      ''
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'Fb7A40', %w(
  | an id58 already used by another test is refused
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) do
        test('Fb7Ax4', %w(| kata exists), &NO_OP)
        test('Fb7Ax4', %w(| kata missing), &NO_OP)
      end
    end
    expected = [
      '',
      '',
      '     !duplicate',
      '     !',
      "test 'Fb7Ax4',",
      "'| kata missing'",
      '',
      ''
    ].join("\n")
    assert_equal expected, error.message
  end

  test 'Fb7A50', %w(
  | a test whose id58 contains none of the command-line args
  | is not defined
  ) do
    klass = Class.new(Id58TestBase) do
      def self.args = ['Kp9']
      test('Fb7Ax5', %w(| kata exists), &NO_OP)
    end
    assert_equal [], klass.public_instance_methods(false)
  end

  test 'Fb7A60', %w(
  | with SHOW_TEST_IDS=true a test prints its id58 and file
  | before running
  ) do
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax6', %w(| kata exists), &NO_OP)
    end
    name = klass.public_instance_methods(false)[0]
    ENV['SHOW_TEST_IDS'] = 'true'
    expected = "\"Fb7Ax6:test_helper_test.rb\"\n"
    assert_output(expected) { klass.new(name).send(name) }
  ensure
    ENV.delete('SHOW_TEST_IDS')
  end

  test 'Fb7A70', %w(
  | a test that raises prints the error's message,
  | then re-raises it
  ) do
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax7', %w(| kata exists)) { raise 'disk full' }
    end
    name = klass.public_instance_methods(false)[0]
    assert_output("disk full\n") do
      assert_raises(RuntimeError) { klass.new(name).send(name) }
    end
  end
end
