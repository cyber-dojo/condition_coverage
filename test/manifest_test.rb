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
    expected = { 'k.rb:2:2' => condition('&&', 16...23, 27...35) }
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
    expected = { 'k.rb:2:2' => condition('||', 16...23, 27...35) }
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
    expected = { 'k.rb:2:2' => condition('&&', *operands) }
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
    both = condition('&&', 16...23, 27...35)
    expected = { 'k.rb:2:2' => condition('||', both, 39...51) }
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
    either = condition('||', 28...36, 40...52)
    expected = { 'k.rb:2:2' => condition('&&', 16...23, either) }
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
    expected = { 'k.rb:2:2' => condition('&&', 16...23, 27...46) }
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
    expected = { 'k.rb:2:2' => condition('&&', 16...23, 27...29) }
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
    both = condition('and', 16...23, 28...36)
    expected = { 'k.rb:2:2' => condition('or', both, 40...52) }
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
    site = condition('and', 16...23, 28...43, commands: [28...43])
    expected = { 'k.rb:2:2' => site }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
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
    expected = {
      'k.rb:2:2' => condition('&&', 16...23, 27...54),
      'k.rb:2:28' => condition('&&', 42...43, 47...52)
    }
    actual = ConditionCoverage::Manifest.sites(source, 'k.rb')
    assert_equal expected, actual
  end
end
