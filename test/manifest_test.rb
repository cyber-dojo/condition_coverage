require_relative 'test_helper'
require 'condition_coverage/manifest'

class ManifestTest < Id58TestBase
  test '6asy10', %w(
  | each && site in a file is found without running it,
  | with its operand count, so an && that never runs
  | can still be reported as missed
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end

      def group?(id)
        return :ok if ok?(id)
      end
    RUBY
    expected = { 'k.rb:2:2' => 2 }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end
end
