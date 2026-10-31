require_relative 'test_helper'
require 'condition_coverage/manifest'

class ManifestTest < Id58TestBase
  test '6asy10', %w(
  | each && site in a file is found without running it,
  | with the byte range of each of its operands, so an &&
  | that never runs can still be reported as missed, and
  | the rewriter and reporters need no parse of their own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id)
      end

      def group?(id)
        return :ok if ok?(id)
      end
    RUBY
    # ok?(id) is bytes 16...23, new?(id) is bytes 27...35
    expected = { 'k.rb:2:2' => [16...23, 27...35] }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end
end
