require_relative 'test_helper'
require 'path_coverage/path_manifest'
require 'path_coverage/rewriter'

class RewriterTest < Id58TestBase
  test '6D1Ka2', %w(
  | each operand of an && is wrapped in a record call
  | keyed by the && site's path:line:column
  | and the operand's index, at the byte ranges
  | the manifest found, with no parse of its own; the
  | whole && is wrapped in a leave call, outside them, whose
  | first argument enters the site, so each evaluation's
  | path through it is counted
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
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 2), ' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      'PathCoverage.record("k.rb:2:2", 1, new?(id)))',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
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
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 3), ' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      '(PathCoverage.record("k.rb:2:2", 1, new?(id)) || ' \
      'PathCoverage.record("k.rb:2:2", 2, id.size == 6)))',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Ka9', %w(
  | a command-call leaf is also wrapped in parentheses of its
  | own, since id.include? 'N' is no bare argument; other
  | leaves are not, as parentheses would give a continuation
  | line a line-coverage count of its own; a whole and or or
  | is no bare argument either, so its leave call holds it
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
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 2), (' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) and ' \
      "PathCoverage.record(\"k.rb:2:2\", 1, (id.include? 'N'))" \
      '))',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
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
    rewriter = PathCoverage::Rewriter
    assert_equal source, rewriter.rewrite(source, {})
  end

  test '6D1Ke1', %w(
  | an if site's leave call wraps its predicate alone, as its
  | path is decided there, so an arm that returns or raises
  | still leaves the site with its path counted
  ) do
    source = <<~RUBY
      def fee(order)
        if order.big?
          return 5
        end
        7
      end
    RUBY
    choice = condition(
      'if', 20...30, arm(:then, 35...43), extent: 17...30
    )
    sites = { 'k.rb:2:2' => choice }
    expected = [
      'def fee(order)',
      '  if PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 1), ' \
      'PathCoverage.record("k.rb:2:2", 0, order.big?))',
      '    return 5',
      '  end',
      '  7',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Ke2', %w(
  | an if site whose predicate is an and or an or holds it
  | in parentheses inside the leave call, as it is no bare
  | argument
  ) do
    source = <<~RUBY
      def k(a, b)
        if a and b
          1
        end
      end
    RUBY
    both = condition('and', 17...18, 23...24, extent: 17...24)
    choice = condition(
      'if', both, arm(:then, 29...30), extent: 14...24
    )
    sites = { 'k.rb:2:2' => choice }
    expected = [
      'def k(a, b)',
      '  if PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 2), ' \
      '(PathCoverage.record("k.rb:2:2", 0, a) and ' \
      'PathCoverage.record("k.rb:2:2", 1, b)))',
      '    1',
      '  end',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Ke3', %w(
  | calls that close at the same offset close innermost
  | first, so a decide call's further argument stays its own
  | when its decision is an if site's predicate
  ) do
    source = <<~RUBY
      def fee(rates)
        if rates.empty?
          return
        end
        1
      end
    RUBY
    choice = condition(
      'if', 20...32, arm(:then, 37...43), extent: 17...32
    )
    sites = { 'k.rb:2:2' => choice }
    methods = {
      'k.rb:1:0' => PathCoverage::PathMethod.new(
        name: :fee,
        entry: 17,
        decisions: [
          PathCoverage::Decision.new(
            line: 2, range: 20...32, command: false, exits: true
          )
        ]
      )
    }
    expected = [
      'def fee(rates)',
      '  __path_coverage_path = ' \
      'PathCoverage.path("k.rb:1:0", 1); ' \
      'if PathCoverage.decide(__path_coverage_path, 0, ' \
      'PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 1), ' \
      'PathCoverage.record("k.rb:2:2", 0, rates.empty?)), true)',
      '    return',
      '  end',
      '  1',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites, methods)
  end

  test '6D1Kc1', %w(
  | a method's path starts just before its first decision,
  | on the same line, and each decision's predicate is
  | wrapped in a decide call outside any record and
  | leave calls in it; a command-call predicate is
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
      'k.rb:1:0' => PathCoverage::PathMethod.new(
        name: :fee,
        entry: 23,
        decisions: [
          PathCoverage::Decision.new(
            line: 2, range: 26...53, command: false
          ),
          PathCoverage::Decision.new(
            line: 5, range: 71...87, command: true
          )
        ]
      )
    }
    expected = [
      'def fee(user, order)',
      '  __path_coverage_path = ' \
      'PathCoverage.path("k.rb:1:0", 2); ' \
      'if PathCoverage.decide(__path_coverage_path, 0, ' \
      'PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:5", 2), ' \
      'PathCoverage.record("k.rb:2:5", 0, user.member?) && ' \
      'PathCoverage.record("k.rb:2:5", 1, order.paid?)))',
      '    5',
      '  end',
      '  if PathCoverage.decide(__path_coverage_path, 1, ' \
      '(order.tier? :big))',
      '    10',
      '  end',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
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
      'k.rb:1:0' => PathCoverage::PathMethod.new(
        name: :fork,
        entry: 15,
        decisions: [
          PathCoverage::Decision.new(
            line: 2, range: 34...47, command: false, exits: true
          ),
          PathCoverage::Decision.new(
            line: 3, range: 53...60, command: false
          )
        ]
      )
    }
    expected = [
      'def fork(id)',
      '  __path_coverage_path = ' \
      'PathCoverage.path("k.rb:1:0", 2); ' \
      "fail 'no group' if PathCoverage.decide(" \
      '__path_coverage_path, 0, id.group.nil?, true)',
      '  if PathCoverage.decide(' \
      '__path_coverage_path, 1, id.odd?)',
      '    1',
      '  end',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, {}, methods)
  end

  test '6D1Kd1', %w(
  | a ternary is wrapped whole, its arms included, in a leave
  | call, so each evaluation's path runs on into the arm its
  | predicate picks
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? :ok : :no
      end
    RUBY
    arms = [arm(:then, 26...29), arm(:else, 32...35)]
    sites = {
      'k.rb:2:2' => condition('?:', 16...23, *arms, extent: 16...35)
    }
    expected = [
      'def kata?(id)',
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 1), ' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) ? :ok : :no)',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Kd3', %w(
  | a ternary whose predicate is a nested condition has that
  | condition's leaves recorded first, as operands 0 and 1
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id) ? :ok : :no
      end
    RUBY
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    arms = [arm(:then, 38...41), arm(:else, 44...47)]
    ternary = condition('?:', both, *arms, extent: 16...47)
    sites = { 'k.rb:2:2' => ternary }
    expected = [
      'def kata?(id)',
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 2), ' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) && ' \
      'PathCoverage.record("k.rb:2:2", 1, new?(id)) ' \
      '? :ok : :no)',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end

  test '6D1Kd4', %w(
  | the leaves of a condition folded in as a ternary's arm
  | are recorded under the ternary's site, numbered on from
  | its predicate's
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? new?(id) && id.size == 6 : :no
      end
    RUBY
    both = condition('&&', 26...34, 38...50, extent: 26...50)
    ternary = condition(
      '?:', 16...23, arm(:then, 26...50, both), arm(:else, 53...56),
      extent: 16...56
    )
    sites = { 'k.rb:2:2' => ternary }
    expected = [
      'def kata?(id)',
      '  PathCoverage.leave(' \
      'PathCoverage.enter("k.rb:2:2", 3), ' \
      'PathCoverage.record("k.rb:2:2", 0, ok?(id)) ? ' \
      'PathCoverage.record("k.rb:2:2", 1, new?(id)) && ' \
      'PathCoverage.record("k.rb:2:2", 2, id.size == 6) : :no)',
      'end',
      ''
    ].join("\n")
    rewriter = PathCoverage::Rewriter
    assert_equal expected, rewriter.rewrite(source, sites)
  end
end
