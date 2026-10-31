require_relative 'test_helper'
require 'condition_coverage/rewriter'

class RewriterTest < Id58TestBase
  test '6D1Ka2', %w(
    each operand of an && is wrapped in a record call
    keyed by the && site's path:line:column
    and the operand's index
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end
    RUBY
    expected =
      "def kata?(id)\n  " \
      'ConditionCoverage.record("k.rb:2:2", 0, ok?(id)) ' \
      '&& ' \
      'ConditionCoverage.record("k.rb:2:2", 1, new?(id))' \
      "\nend\n"
    rewriter = ConditionCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, 'k.rb')
  end
end
