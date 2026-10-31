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
    sites = { 'k.rb:2:2' => [16...23, 27...35] }
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
