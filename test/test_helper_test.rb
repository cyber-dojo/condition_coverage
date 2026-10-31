require_relative 'test_helper'

class TestHelperTest < Id58TestBase
  # Serial, so assert_output's capture of $stdout cannot catch
  # another thread's output: Minitest runs serial suites before
  # parallel ones.
  def self.run_order = :random

  # The body of a throwaway test that is defined, never run.
  NO_OP = proc { :no_op }

  test 'Fb7A10', %w(
    a running test can read its own id58 and description
  ) do
    assert_equal 'Fb7A10', id58
    words = 'a running test can read its own id58 and description'
    assert_equal words, name58
  end

  test 'Fb7A20', %w(
    an empty id58 is refused, pointing at the offending test
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) { test('', %w(kata exists), &NO_OP) }
    end
    expected = "\n\n     !empty\n     !\ntest '',\n'kata exists'\n\n"
    assert_equal expected, error.message
  end

  test 'Fb7A30', %w(
    an id58 using a letter outside the alphabet is refused
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) do
        test('Fb7AO1', %w(kata exists), &NO_OP)
      end
    end
    expected =
      "\n\n     !not id58\n     !\n" \
      "test 'Fb7AO1',\n'kata exists'\n\n"
    assert_equal expected, error.message
  end

  test 'Fb7A40', %w(
    an id58 already used by another test is refused
  ) do
    error = assert_raises(RuntimeError) do
      Class.new(Id58TestBase) do
        test('Fb7Ax4', %w(kata exists), &NO_OP)
        test('Fb7Ax4', %w(kata missing), &NO_OP)
      end
    end
    expected =
      "\n\n     !duplicate\n     !\n" \
      "test 'Fb7Ax4',\n'kata missing'\n\n"
    assert_equal expected, error.message
  end

  test 'Fb7A50', %w(
    a test whose id58 contains none of the command-line args
    is not defined
  ) do
    klass = Class.new(Id58TestBase) do
      def self.args = ['Kp9']
      test('Fb7Ax5', %w(kata exists), &NO_OP)
    end
    assert_equal [], klass.public_instance_methods(false)
  end

  test 'Fb7A60', %w(
    with SHOW_TEST_IDS=true a test prints its id58 and file
    before running
  ) do
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax6', %w(kata exists), &NO_OP)
    end
    name = klass.public_instance_methods(false)[0]
    ENV['SHOW_TEST_IDS'] = 'true'
    expected = "\"Fb7Ax6:test_helper_test.rb\"\n"
    assert_output(expected) { klass.new(name).send(name) }
  ensure
    ENV.delete('SHOW_TEST_IDS')
  end

  test 'Fb7A70', %w(
    a test that raises prints the error's message,
    then re-raises it
  ) do
    klass = Class.new(Id58TestBase) do
      test('Fb7Ax7', %w(kata exists)) { raise 'disk full' }
    end
    name = klass.public_instance_methods(false)[0]
    assert_output("disk full\n") do
      assert_raises(RuntimeError) { klass.new(name).send(name) }
    end
  end
end
