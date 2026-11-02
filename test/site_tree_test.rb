require_relative 'test_helper'
require 'condition_coverage/site_tree'

class SiteTreeTest < Id58TestBase
  test 'EuNs10', %w(
  | a site's tree names its operator and has a column for
  | each of its paths, never taken first, with each path's
  | count; each leaf has its source text, cut from the
  | manifest's byte range with no parse, and its outcome on
  | each path, nil where unreached; the site its value
  ) do
    source = <<~RUBY
      module Kata
        def self.ok?(id) = !id.empty?
        def self.kata?(id) = ok?(id) && id.start_with?('N')
      end
    RUBY
    site = condition('&&', 67...74, 78...97)
    paths = [
      { path: [true, true], count: 1 },
      { path: [true, false], count: 0 },
      { path: [false, nil], count: 1 }
    ]
    expected = {
      operator: '&&', counts: [0, 1, 1],
      cells: [false, true, false],
      operands: [
        { text: 'ok?(id)', cells: [true, true, false] },
        { text: "id.start_with?('N')", cells: [false, true, nil] }
      ]
    }
    actual = ConditionCoverage::SiteTree.of(source, site, paths)
    assert_equal expected, actual
  end

  test 'EuNs30', %w(
  | a nested condition is a subtree under its operator, its
  | leaves taking their outcomes in left to right order, and
  | its value on each path that of the last operand it reached
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && (new?(id) || id.size == 6)
      end
    RUBY
    either = condition('||', 28...36, 40...52)
    site = condition('&&', 16...23, either)
    paths = [
      { path: [true, true, nil], count: 2 },
      { path: [true, false, true], count: 0 },
      { path: [true, false, false], count: 1 },
      { path: [false, nil, nil], count: 1 }
    ]
    expected = {
      operator: '&&', counts: [0, 2, 1, 1],
      cells: [true, true, false, false],
      operands: [
        { text: 'ok?(id)', cells: [true, true, true, false] },
        {
          operator: '||', cells: [true, true, false, nil],
          operands: [
            { text: 'new?(id)', cells: [false, true, false, nil] },
            { text: 'id.size == 6', cells: [true, nil, false, nil] }
          ]
        }
      ]
    }
    actual = ConditionCoverage::SiteTree.of(source, site, paths)
    assert_equal expected, actual
  end

  test 'EuNs70', %w(
  | a ternary's predicate decides which arm each path took;
  | each arm has its text, the tree of the condition it holds,
  | nil for a plain arm, and whether each path took it; the
  | ternary's value on a path is its taken arm's, nil for a
  | plain arm
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? new?(id) && id.size == 6 : :no
      end
    RUBY
    both = condition('&&', 26...34, 38...50)
    site = condition(
      '?:', 16...23, arm(:then, 26...50, both), arm(:else, 53...56)
    )
    paths = [
      { path: [true, true, true], count: 1 },
      { path: [true, true, false], count: 0 },
      { path: [true, false, nil], count: 2 },
      { path: [false, nil, nil], count: 3 }
    ]
    expected = {
      operator: '?:', counts: [0, 1, 2, 3],
      cells: [false, true, false, nil],
      operands: [
        { text: 'ok?(id)', cells: [true, true, true, false] },
        {
          arm: :then, text: 'new?(id) && id.size == 6',
          cells: [true, true, true, false],
          body: {
            operator: '&&', cells: [false, true, false, nil],
            operands: [
              { text: 'new?(id)', cells: [true, true, false, nil] },
              { text: 'id.size == 6', cells: [false, true, nil, nil] }
            ]
          }
        },
        {
          arm: :else, text: ':no',
          cells: [false, false, false, true], body: nil
        }
      ]
    }
    actual = ConditionCoverage::SiteTree.of(source, site, paths)
    assert_equal expected, actual
  end
end
