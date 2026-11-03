require_relative 'test_helper'
require 'path_coverage/site_paths'

class SitePathsTest < Id58TestBase
  test 'Sp3x10', %w(
  | the possible paths through an && are every way its
  | leaves can be evaluated, true before false, a leaf an
  | && never reaches being nil
  ) do
    # ok?(id) && new?(id)
    site = condition('&&', 16...23, 27...35)
    expected = [[true, true], [true, false], [false, nil]]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x20', %w(
  | an || stops at its first true leaf, so a leaf after one
  | that was true is nil
  ) do
    # ok?(id) || new?(id)
    site = condition('||', 16...23, 27...35)
    expected = [[true, nil], [false, true], [false, false]]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x30', %w(
  | a ternary's path goes from its predicate into the arm
  | its predicate picks, through any condition that arm is,
  | the other arm's leaves being nil
  ) do
    # ok?(id) ? new?(id) && id.size == 6 : :no
    both = condition('&&', 26...34, 38...50)
    site = condition(
      '?:', 16...23, arm(:then, 26...50, both), arm(:else, 53...56)
    )
    expected = [
      [true, true, true], [true, true, false],
      [true, false, nil], [false, nil, nil]
    ]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x40', %w(
  | a fixed leaf has its one outcome only, at any depth, so
  | a path needing its other outcome is impossible, not a gap
  ) do
    # opts[:v] || false ? :loud : :quiet
    either = condition('||', 16...24, 28...33)
    site = condition(
      '?:', either, arm(:then, 36...41), arm(:else, 44...50),
      fixed: { 28...33 => :falsy }
    )
    expected = [[true, nil], [false, false]]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x50', %w(
  | a nested condition's own outcome decides whether the
  | chain around it goes on, as Ruby's short-circuit does
  ) do
    # ok?(id) && new?(id) || id.size == 6
    both = condition('&&', 16...23, 27...35)
    site = condition('||', both, 39...51)
    expected = [
      [true, true, nil], [true, false, true], [true, false, false],
      [false, nil, true], [false, nil, false]
    ]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x60', %w(
  | Example: if order.big? && order.new?
  | The if's paths are its predicate's paths.
  | Its arms add no paths of their own.
  | It has no else arm, but still has a false path.
  ) do
    both = condition('&&', 20...30, 34...44)
    site = condition('if', both, arm(:then, 49...50))
    expected = [[true, true], [true, false], [false, nil]]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x70', %w(
  | Example: unless order.big?
  | The unless's paths are its predicate's paths.
  | That is the same as for an if.
  ) do
    site = condition('unless', 24...34, arm(:then, 39...40))
    expected = [[true], [false]]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x80', %w(
  | Example: case x when 1, 2 ... when String ... else ... end
  | The case tries its patterns in order: 1, 2, String.
  | The first pattern that matches ends the path.
  | The patterns after it are never tried, so they are nil.
  | When none match, the path is all false (the else).
  ) do
    small = condition('when', 28...29, 31...32)
    text = condition('when', 51...57)
    site = condition(
      'case', arm(:when, 37...43, small), arm(:when, 62...67, text),
      arm(:else, 79...85)
    )
    expected = [
      [true, nil, nil], [false, true, nil],
      [false, false, true], [false, false, false]
    ]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x90', %w(
  | Example: ids.any? { |id| id.ok? }
  | any? can stop early, so its block's last answer decides it.
  | A path has two parts.
  | First, how many ids the block was called with:
  | 0 items, 1 item, or 2+ items.
  | Second, the block's last answer: true or false.
  | With 0 items the block was never called, so it is nil.
  ) do
    site = condition('any?', 13...16, 29...35)
    expected = [
      ['0 items', nil], ['1 item', true], ['1 item', false],
      ['2+ items', true], ['2+ items', false]
    ]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end

  test 'Sp3x91', %w(
  | Example: ids.select { |id| id.ok? }
  | select calls its block with every item.
  | A path has two parts.
  | First, how many ids: 0 items, 1 item, or 2+ items.
  | Second, the block's answers: all true, all false, or both.
  | Both needs 2+ items.
  | With 0 items the block was never called, so it is nil.
  ) do
    site = condition('select', 13...16, 31...37)
    expected = [
      ['0 items', nil],
      ['1 item', 'all true'], ['1 item', 'all false'],
      ['2+ items', 'all true'], ['2+ items', 'all false'],
      ['2+ items', 'both']
    ]
    assert_equal expected, PathCoverage::SitePaths.possible(site)
  end
end
