require_relative 'test_helper'
require 'condition_coverage/site_paths'

class SitePathsTest < Id58TestBase
  test 'Sp3x10', %w(
  | the possible paths through an && are every way its
  | leaves can be evaluated, true before false, a leaf an
  | && never reaches being nil
  ) do
    # ok?(id) && new?(id)
    site = condition('&&', 16...23, 27...35)
    expected = [[true, true], [true, false], [false, nil]]
    assert_equal expected, ConditionCoverage::SitePaths.possible(site)
  end

  test 'Sp3x20', %w(
  | an || stops at its first true leaf, so a leaf after one
  | that was true is nil
  ) do
    # ok?(id) || new?(id)
    site = condition('||', 16...23, 27...35)
    expected = [[true, nil], [false, true], [false, false]]
    assert_equal expected, ConditionCoverage::SitePaths.possible(site)
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
    assert_equal expected, ConditionCoverage::SitePaths.possible(site)
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
    assert_equal expected, ConditionCoverage::SitePaths.possible(site)
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
    assert_equal expected, ConditionCoverage::SitePaths.possible(site)
  end
end
