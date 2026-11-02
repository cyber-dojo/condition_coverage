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
    site = condition('&&', 67...74, 78...97)
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
    actual = ConditionCoverage::SiteTree.of(source, site, counts)
    assert_equal expected, actual
  end

  test 'EuNs20', %w(
  | an || site's tree is named by its || operator
  ) do
    source = <<~RUBY
      module Kata
        def self.ok?(id) = !id.empty?
        def self.kata?(id) = ok?(id) || id.start_with?('N')
      end
    RUBY
    site = condition('||', 67...74, 78...97)
    counts = [
      { truthy: 1, falsy: 1 },
      { truthy: 1, falsy: 1 }
    ]
    tree = ConditionCoverage::SiteTree.of(source, site, counts)
    assert_equal '||', tree[:operator]
  end

  test 'EuNs30', %w(
  | a nested condition is a subtree under its operator,
  | its leaves taking their counts in left to right order
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && (new?(id) || id.size == 6)
      end
    RUBY
    either = condition('||', 28...36, 40...52)
    site = condition('&&', 16...23, either)
    counts = [
      { truthy: 2, falsy: 1 },
      { truthy: 1, falsy: 1 },
      { truthy: 0, falsy: 1 }
    ]
    expected = {
      operator: '&&',
      operands: [
        { text: 'ok?(id)', truthy: 2, falsy: 1, gap: nil },
        {
          operator: '||',
          operands: [
            { text: 'new?(id)', truthy: 1, falsy: 1, gap: nil },
            { text: 'id.size == 6', truthy: 0, falsy: 1,
              gap: 'never true' }
          ]
        }
      ]
    }
    actual = ConditionCoverage::SiteTree.of(source, site, counts)
    assert_equal expected, actual
  end

  test 'EuNs40', %w(
  | given its site's own outcome, a tree's root has that
  | outcome's true and false counts and its gap, so a
  | ternary shows which of its arms ran
  ) do
    source = <<~RUBY
      module Fee
        def self.fee(u) = u[:a] || u[:b] ? 5 : 7
      end
    RUBY
    either = condition('||', 31...36, 40...45)
    site = condition('?:', either)
    counts = [
      { truthy: 1, falsy: 1 },
      { truthy: 1, falsy: 0 }
    ]
    outcome = { truthy: 2, falsy: 0, ternary: true }
    expected = {
      operator: '?:', truthy: 2, falsy: 0, gap: 'never false',
      operands: [
        {
          operator: '||',
          operands: [
            { text: 'u[:a]', truthy: 1, falsy: 1, gap: nil },
            { text: 'u[:b]', truthy: 1, falsy: 0,
              gap: 'never false' }
          ]
        }
      ]
    }
    tree = ConditionCoverage::SiteTree
    assert_equal expected, tree.of(source, site, counts, outcome)
  end

  test 'EuNs50', %w(
  | any site's root shows its own outcome's gap, eg an && never
  | true, though only a ternary's is listed among the gaps
  ) do
    source = <<~RUBY
      module Shop
        def self.loud? = VERBOSE && $stdout.tty?
      end
    RUBY
    site = condition('&&', 30...37, 41...53)
    counts = [
      { truthy: 0, falsy: 1 },
      { truthy: 0, falsy: 0 }
    ]
    outcome = { truthy: 0, falsy: 1 }
    tree = ConditionCoverage::SiteTree.of(source, site, counts, outcome)
    assert_equal 'never true', tree[:gap]
  end
end
