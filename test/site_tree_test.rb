require_relative 'test_helper'
require 'condition_coverage/site_tree'

class SiteTreeTest < Id58TestBase
  test 'EuNs10', %w(
  | a site's tree names its operator, and gives each operand
  | its source text, cut from the manifest's byte range with
  | no parse, its true and false counts, and its gap
  ) do
    source = <<~RUBY
      module Kata
        def self.ok?(id) = !id.empty?
        def self.kata?(id) = ok?(id) && id.start_with?('N')
      end
    RUBY
    ranges = [67...74, 78...97]
    counts = [
      { truthy: 1, falsy: 1 },
      { truthy: 1, falsy: 0 }
    ]
    expected = {
      operator: '&&',
      operands: [
        { text: 'ok?(id)', truthy: 1, falsy: 1, gap: nil },
        { text: "id.start_with?('N')", truthy: 1, falsy: 0,
          gap: 'never false' }
      ]
    }
    actual = ConditionCoverage::SiteTree.of(source, ranges, counts)
    assert_equal expected, actual
  end
end
