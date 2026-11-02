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
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    expected = { 'k.rb:2:2' => both }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy20', %w(
  | each || site is found too, named by its operator,
  | with the byte range of each of its operands
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) || new?(id)
      end
    RUBY
    either = condition('||', 16...23, 27...35, extent: 16...35)
    expected = { 'k.rb:2:2' => either }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy30', %w(
  | a chain of one operator is a single site,
  | flat, with one operand per link in the chain
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id) && id.size == 6
      end
    RUBY
    operands = [16...23, 27...35, 39...51]
    chain = condition('&&', *operands, extent: 16...51)
    expected = { 'k.rb:2:2' => chain }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy40', %w(
  | an operand that is itself a condition of the other operator
  | nests inside its site as Ruby's precedence groups it,
  | rather than being a site of its own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id) || id.size == 6
      end
    RUBY
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    either = condition('||', both, 39...51, extent: 16...51)
    expected = { 'k.rb:2:2' => either }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy50', %w(
  | a condition grouped in parentheses nests inside its site
  | as the parentheses group it, the parentheses themselves
  | being no part of the tree since they decide nothing
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && (new?(id) || id.size == 6)
      end
    RUBY
    # the site's extent takes in the closing parenthesis
    either = condition('||', 28...36, 40...52, extent: 28...52)
    both = condition('&&', 16...23, either, extent: 16...53)
    expected = { 'k.rb:2:2' => both }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy60', %w(
  | parentheses holding several statements are one leaf
  | operand, since only their last statement's value decides
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && (log(id); new?(id))
      end
    RUBY
    both = condition('&&', 16...23, 27...46, extent: 16...46)
    expected = { 'k.rb:2:2' => both }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy70', %w(
  | empty parentheses are one leaf operand, always nil
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && ()
      end
    RUBY
    both = condition('&&', 16...23, 27...29, extent: 16...29)
    expected = { 'k.rb:2:2' => both }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy75', %w(
  | a site is named by its operator as written,
  | so and and or are not shown as && and ||
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) and new?(id) or id.size == 6
      end
    RUBY
    both = condition('and', 16...23, 28...36, extent: 16...36)
    either = condition('or', both, 40...52, extent: 16...52)
    expected = { 'k.rb:2:2' => either }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy77', %w(
  | a leaf that is a command call, eg id.include? 'N' after
  | an and, is named among the condition's commands, since
  | it needs parentheses of its own to be an argument
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) and id.include? 'N'
      end
    RUBY
    site = condition(
      'and', 16...23, 28...43, commands: [28...43], extent: 16...43
    )
    expected = { 'k.rb:2:2' => site }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy78', %w(
  | a leaf that can only be truthy, eg MonotonicClock.new,
  | is named among the condition's fixed leaves, so its
  | never false is not reported as a gap
  ) do
    source = <<~RUBY
      def initialize(options)
        @clock = options[:clock] || MonotonicClock.new
      end
    RUBY
    fixed = { 54...72 => :truthy }
    site = condition('||', 35...50, 54...72, fixed:, extent: 35...72)
    expected = { 'k.rb:2:11' => site }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy79', %w(
  | literals and lambdas can only be truthy, and nil and false
  | only falsy, so each is a fixed leaf with that outcome
  ) do
    source = <<~RUBY
      def defaults(o)
        @a = o[:a] || 'anon'
        @b = o[:b] || 1
        @c = o[:c] || :none
        @d = o[:d] || []
        @e = o[:e] || {}
        @f = o[:f] || true
        @g = o[:g] || -> { 0 }
        @h = o[:h] || nil
        @i = o[:i] || false
      end
    RUBY
    sites = ConditionCoverage::Manifest.sites(source, 'k.rb')
    actual = sites.values.map(&:fixed).reduce({}, :merge)
                  .transform_keys { |range| source.byteslice(range) }
    expected = {
      "'anon'" => :truthy, '1' => :truthy, ':none' => :truthy,
      '[]' => :truthy, '{}' => :truthy, 'true' => :truthy,
      '-> { 0 }' => :truthy, 'nil' => :falsy, 'false' => :falsy
    }
    assert_equal expected, actual
  end

  test '6asy7a', %w(
  | a constant, eg LATEST or Config::DEFAULT, is no fixed
  | leaf, since it can hold nil or false, eg VERBOSE = false
  ) do
    source = <<~RUBY
      def tagged(match)
        tag = match[8] || LATEST
        host = match[2] || Config::DEFAULT
        "\#{host}:\#{tag}"
      end
    RUBY
    sites = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal [{}, {}], sites.values.map(&:fixed)
  end

  test '6asy7b', %w(
  | $stdout and $stderr are truthy only, as Ruby refuses nil
  | or false for either; $stdin accepts both, so it is not
  | fixed
  ) do
    source = <<~RUBY
      def streams
        out = Thread.current[:out] || $stdout
        err = Thread.current[:err] || $stderr
        inp = Thread.current[:inp] || $stdin
        [out, err, inp]
      end
    RUBY
    sites = ConditionCoverage::Manifest.sites(source, 'k.rb')
    actual = sites.values.map(&:fixed).reduce({}, :merge)
                  .transform_keys { |range| source.byteslice(range) }
    expected = { '$stdout' => :truthy, '$stderr' => :truthy }
    assert_equal expected, actual
  end

  test '6asy80', %w(
  | a condition inside a leaf operand, eg in a block,
  | decides something else, so it is a site of its own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && ids.any? { |k| k && k.ok? }
      end
    RUBY
    outer = condition('&&', 16...23, 27...54, extent: 16...54)
    inner = condition('&&', 42...43, 47...52, extent: 42...52)
    expected = { 'k.rb:2:2' => outer, 'k.rb:2:28' => inner }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy90', %w(
  | a ternary is a choice too, so it is a site, named ?:,
  | whose operands are its predicate and its two arms, and
  | whose extent is the whole ternary
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? :ok : :no
      end
    RUBY
    arms = [arm(:then, 26...29), arm(:else, 32...35)]
    ternary = condition('?:', 16...23, *arms, extent: 16...35)
    expected = { 'k.rb:2:2' => ternary }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy91', %w(
  | a ternary whose predicate is an && nests the &&
  | inside its site, as an operand of the other operator
  | nests, rather than the && being a site of its own
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) && new?(id) ? :ok : :no
      end
    RUBY
    both = condition('&&', 16...23, 27...35, extent: 16...35)
    arms = [arm(:then, 38...41), arm(:else, 44...47)]
    ternary = condition('?:', both, *arms, extent: 16...47)
    expected = { 'k.rb:2:2' => ternary }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy92', %w(
  | a condition that is a ternary's arm is part of the one
  | expression, so it folds into the ternary's site as that
  | arm's body, and a plain arm is an arm with no body
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
    expected = { 'k.rb:2:2' => ternary }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy93', %w(
  | a condition that is a ternary's else arm folds into the
  | ternary's site too
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? :ok : new?(id) && id.size == 6
      end
    RUBY
    both = condition('&&', 32...40, 44...56, extent: 32...56)
    ternary = condition(
      '?:', 16...23, arm(:then, 26...29), arm(:else, 32...56, both),
      extent: 16...56
    )
    expected = { 'k.rb:2:2' => ternary }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy94', %w(
  | a condition inside a plain arm, eg in a block, decides
  | something else, so it is a site of its own, after the
  | ternary's
  ) do
    source = <<~RUBY
      def kata?(id)
        ok?(id) ? ids.any? { |k| k && k.ok? } : :no
      end
    RUBY
    ternary = condition(
      '?:', 16...23, arm(:then, 26...53), arm(:else, 56...59),
      extent: 16...59
    )
    inner = condition('&&', 41...42, 46...51, extent: 41...51)
    expected = { 'k.rb:2:2' => ternary, 'k.rb:2:27' => inner }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end

  test '6asy95', %w(
  | a ternary that is an arm of a ternary, in parentheses,
  | folds in as that arm's body, so the whole expression is
  | one site
  ) do
    source = <<~RUBY
      def k(x, y)
        x ? (y ? 1 : 2) : 3
      end
    RUBY
    inner = condition(
      '?:', 19...20, arm(:then, 23...24), arm(:else, 27...28),
      extent: 19...28
    )
    outer = condition(
      '?:', 14...15, arm(:then, 18...29, inner), arm(:else, 32...33),
      extent: 14...33
    )
    expected = { 'k.rb:2:2' => outer }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end
end
