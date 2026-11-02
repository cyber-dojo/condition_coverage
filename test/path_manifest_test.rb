require_relative 'test_helper'
require 'condition_coverage/path_manifest'

class PathManifestTest < Id58TestBase
  test 'Pm7c01', %w(
  | each def is named by its path:line:column and lists the
  | ifs at the top level of its body as its decisions, each
  | with its line and the byte range of its predicate, so
  | each call's path is the outcomes of those ifs in order
  ) do
    source = <<~RUBY
      def fee(user, order)
        total = order.total
        if user.member?
          total -= 5
        end
        if order.big?
          total -= 10
        end
        total
      end
    RUBY
    expected = {
      'k.rb:1:0' => path_method(
        :fee, 45, decision(3, 48...60), decision(6, 87...97)
      )
    }
    assert_equal expected, methods(source)
  end

  test 'Pm7c02', %w(
  | a def with fewer than two top-level ifs is left out, an
  | empty one included, as its paths are no more than the
  | branches branch coverage already counts
  ) do
    source = <<~RUBY
      class Shop
        def open?
        end

        def fee(user)
          if user.member?
            5
          end
        end
      end
    RUBY
    assert_equal({}, methods(source))
  end

  test 'Pm7c03', %w(
  | a def with a rescue has the ifs before its rescue as its
  | decisions, and an endless def, having no statements,
  | has none
  ) do
    source = <<~RUBY
      def fee(user)
        if user.member?
          5
        end
        if user.new?
          1
        end
      rescue KeyError
        0
      end
      def zero = 0
    RUBY
    expected = {
      'k.rb:1:0' => path_method(
        :fee, 16, decision(2, 19...31), decision(5, 49...58)
      )
    }
    assert_equal expected, methods(source)
  end

  test 'Pm7c04', %w(
  | a predicate that is a command call, eg user.tier? :gold,
  | is marked as one, as it is no bare argument
  ) do
    source = <<~RUBY
      def fee(user)
        if user.tier? :gold
          5
        end
        if user.new?
          1
        end
      end
    RUBY
    decisions = methods(source)['k.rb:1:0'].decisions
    assert_equal [true, false], decisions.map(&:command)
  end

  test 'Pm7c05', %w(
  | a decision whose arm always leaves the method, by
  | fail, raise or return as its last statement, notes the
  | outcome that leaves, since a call taking it decides
  | no more; one with no such arm notes none
  ) do
    source = <<~RUBY
      def fork(id, index)
        fail 'not in a group' if id.group.nil?
        if index.negative?
          return nil
        end
        if index > 9
          index -= 1
        else
          raise ArgumentError, 'too small'
        end
        if index.odd?
          index += 1
        end
        index
      end
    RUBY
    decisions = methods(source)['k.rb:1:0'].decisions
    assert_equal [true, true, false, nil], decisions.map(&:exits)
  end

  test 'Pm7c06', %w(
  | an arm holding only a comment has no statements, so it
  | is not one that leaves the method
  ) do
    source = <<~RUBY
      def align(index)
        if index.odd?
          # odd indexes are already aligned
        else
          index += 1
        end
        if index > 9
          index = 9
        end
        index
      end
    RUBY
    decisions = methods(source)['k.rb:1:0'].decisions
    assert_equal [nil, nil], decisions.map(&:exits)
  end

  test 'Pm7c07', %w(
  | a def inside a def is a method of its own, with its own
  | decisions, none of which are decisions of the def
  | around it
  ) do
    source = <<~RUBY
      def install(rates)
        if rates.empty?
          return
        end
        def discount(total, rate)
          if rate.positive?
            total *= rate
          end
          if total > 100
            total = 100
          end
          total
        end
        if rates.size > 1
          @tiered = true
        end
      end
    RUBY
    lines = methods(source).transform_values do |method|
      method.decisions.map(&:line)
    end
    expected = { 'k.rb:1:0' => [2, 14], 'k.rb:5:2' => [6, 9] }
    assert_equal expected, lines
  end

  private

  # The path manifest of source, as if it were k.rb.
  def methods(source)
    ConditionCoverage::PathManifest.methods(source, 'k.rb')
  end

  # The PathMethod named name, with entry and decisions.
  def path_method(name, entry, *decisions)
    ConditionCoverage::PathMethod.new(name:, entry:, decisions:)
  end

  # The Decision at line whose predicate is at range.
  def decision(line, range, command: false)
    ConditionCoverage::Decision.new(line:, range:, command:)
  end
end
