require_relative 'test_helper'
require 'condition_coverage/rewriter'

class RewriterTest < Id58TestBase
  test '6D1Ka2', %w(
  | each operand of an && is wrapped in a record call
  | keyed by the && site's path:line:column
  | and the operand's index, at the byte ranges
  | the manifest found, with no parse of its own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end
    RUBY
    sites = { 'k.rb:2:2' => condition('&&', 16...23, 27...35) }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      'ConditionCoverage.record("k.rb:2:2", 1, new?(id))',
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
    either = condition('||', 28...36, 40...52)
    sites = { 'k.rb:2:2' => condition('&&', 16...23, either) }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      '(ConditionCoverage.record("k.rb:2:2", 1, new?(id)) || ' \
      'ConditionCoverage.record("k.rb:2:2", 2, id.size == 6))',
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
  | line a line-coverage count of its own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) and id.include? 'N'
      end
    RUBY
    site = condition('and', 16...23, 28...43, commands: [28...43])
    sites = { 'k.rb:2:2' => site }
    expected = [
      'def kata?(id)',
      '  ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) and ' \
      "ConditionCoverage.record(\"k.rb:2:2\", 1, (id.include? 'N'))",
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
end
