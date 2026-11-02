require_relative 'test_helper'
require 'condition_coverage/path_manifest'
require 'condition_coverage/rewriter'

class RewriterTest < Id58TestBase
  test '6D1Ka2', %w(
  | each operand of an && is wrapped in a record call
  | keyed by the && site's path:line:column
  | and the operand's index, at the byte ranges
  | the manifest found, with no parse of its own; the
  | whole && is wrapped in an outcome call, outside them,
  | so its own value is counted too
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end
    RUBY
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    sites = { 'k.rb:2:2' => both }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.outcome("k.rb:2:2", ' \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      'ConditionCoverage.record("k.rb:2:2", 1, new?(id)))',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Ka8', %w(
  | the leaves of a nested condition are wrapped too,
  | indexed left to right across the whole site,
  | and the parentheses grouping them are kept
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && (new?(id) || id.size == 6)
      end
    RUBY
    either = condition('||', 28...36, 40...52, extent: 28...52)
    both = condition('&&', 16...23, either, extent: 16...53)
    sites = { 'k.rb:2:2' => both }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.outcome("k.rb:2:2", ' \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      '(ConditionCoverage.record("k.rb:2:2", 1, new?(id)) || ' \
      'ConditionCoverage.record("k.rb:2:2", 2, id.size == 6)))',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Ka9', %w(
  | a command-call leaf is also wrapped in parentheses of its
  | own, since id.include? 'N' is no bare argument; other
  | leaves are not, as parentheses would give a continuation
  | line a line-coverage count of its own; a whole and or or
  | is no bare argument either, so its outcome call holds it
  | in parentheses
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) and id.include? 'N'
      end
    RUBY
    site = condition(
      'and', 16...23, 28...43, commands: [28...43], extent: 16...43
    )
    sites = { 'k.rb:2:2' => site }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.outcome("k.rb:2:2", (' \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) and ' \
      "ConditionCoverage.record(\"k.rb:2:2\", 1, (id.include? 'N'))" \
      '))',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Kb4', %w(
  | a file with no && sites is returned unchanged
  ) do
    source = <<~RUBY
      def kata?(id)
        return :ok if ok?(id)
      end
    RUBY
    rewriter = ConditionCoverage::Rewriter
    assert_equal source, rewriter.rewrite(source, {})
  end

  test '6D1Kc1', %w(
  | a method's path starts just before its first decision,
  | on the same line, and each decision's predicate is
  | wrapped in a decide call outside any record and
  | outcome calls in it; a command-call predicate is
  | parenthesised
  ) do
    source = <<~RUBY
      def fee(user, order)
        if user.member? && order.paid?
          5
        end
        if order.tier? :big
          10
        end
      end
    RUBY
    both = condition('&&', 26...38, 42...53, extent: 26...53)
    sites = { 'k.rb:2:5' => both }
    methods = {
      'k.rb:1:0' => ConditionCoverage::PathMethod.new(
        name: :fee,
        entry: 23,
        decisions: [
          ConditionCoverage::Decision.new(
            line: 2, range: 26...53, command: false
          ),
          ConditionCoverage::Decision.new(
            line: 5, range: 71...87, command: true
          )
        ]
      )
    }
    expected = [
      'def fee(user, order)',
      '  __condition_coverage_path = ' \
      'ConditionCoverage.path("k.rb:1:0", 2); ' \
      'if ConditionCoverage.decide(__condition_coverage_path, 0, ' \
      'ConditionCoverage.outcome("k.rb:2:5", ' \
      'ConditionCoverage.record("k.rb:2:5", 0, user.member?) && ' \
      'ConditionCoverage.record("k.rb:2:5", 1, order.paid?)))',
      '    5',
      '  end',
      '  if ConditionCoverage.decide(__condition_coverage_path, 1, ' \
      '(order.tier? :big))',
      '    10',
      '  end',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites, methods)
  end

  test '6D1Kc2', %w(
  | a decision whose arm always leaves the method passes
  | decide the outcome that leaves, so the path is counted
  | there, cut short
  ) do
    source = <<~RUBY
      def fork(id)
        fail 'no group' if id.group.nil?
        if id.odd?
          1
        end
      end
    RUBY
    methods = {
      'k.rb:1:0' => ConditionCoverage::PathMethod.new(
        name: :fork,
        entry: 15,
        decisions: [
          ConditionCoverage::Decision.new(
            line: 2, range: 34...47, command: false, exits: true
          ),
          ConditionCoverage::Decision.new(
            line: 3, range: 53...60, command: false
          )
        ]
      )
    }
    expected = [
      'def fork(id)',
      '  __condition_coverage_path = ' \
      'ConditionCoverage.path("k.rb:1:0", 2); ' \
      "fail 'no group' if ConditionCoverage.decide(" \
      '__condition_coverage_path, 0, id.group.nil?, true)',
      '  if ConditionCoverage.decide(' \
      '__condition_coverage_path, 1, id.odd?)',
      '    1',
      '  end',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, {}, methods)
  end

  test '6D1Kd1', %w(
  | a ternary's predicate is wrapped in an outcome call,
  | outside its leaves' record calls, so the arm it chose
  | is counted for the site as a whole
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? :ok : :no
      end
    RUBY
    sites = {
      'k.rb:2:2' => condition('?:', 16...23, extent: 16...35)
    }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.outcome("k.rb:2:2", ' \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id))) ? :ok : :no',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Kd3', %w(
  | a ternary whose predicate is a nested condition has that
  | whole condition wrapped in its outcome call
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id) ? :ok : :no
      end
    RUBY
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    sites = { 'k.rb:2:2' => condition('?:', both, extent: 16...47) }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.outcome("k.rb:2:2", ' \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      'ConditionCoverage.record("k.rb:2:2", 1, new?(id))) ' \
      '? :ok : :no',
      'end',
      ''
    ].join("\n")
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end
end
