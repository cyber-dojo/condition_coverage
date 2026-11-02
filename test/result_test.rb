require_relative 'test_helper'
require 'path_coverage/result'

class ResultTest < Id58TestBase
  test 'DYTY10', %w(
  | the result lists every site in the manifest
  | with the counts of each of its operands,
  | zero for an operand or a whole site that never ran
  ) do
    sites = {
      'k.rb:2:2' => condition('&&', 16...23, 27...35),
      'k.rb:6:4' => condition('&&', 57...64, 68...77)
    }
    counts = {
      ['k.rb:2:2', 0] => { truthy: 2, falsy: 1 },
      ['k.rb:2:2', 1] => { truthy: 1, falsy: 1 }
    }
    expected = {
      'k.rb:2:2' => [
        { truthy: 2, falsy: 1 },
        { truthy: 1, falsy: 1 }
      ],
      'k.rb:6:4' => [
        { truthy: 0, falsy: 0 },
        { truthy: 0, falsy: 0 }
      ]
    }
    actual = PathCoverage::Result.new(sites, counts).operands
    assert_equal expected, actual
  end

  test 'DYTY20', %w(
  | the counts of a leaf that can have one outcome only
  | say which, so reporters demand that outcome alone
  ) do
    fixed = { 54...72 => :truthy }
    sites = {
      'k.rb:2:11' => condition('||', 35...50, 54...72, fixed:)
    }
    counts = {
      ['k.rb:2:11', 0] => { truthy: 1, falsy: 1 },
      ['k.rb:2:11', 1] => { truthy: 1, falsy: 0 }
    }
    expected = {
      'k.rb:2:11' => [
        { truthy: 1, falsy: 1 },
        { truthy: 1, falsy: 0, only: :truthy }
      ]
    }
    actual = PathCoverage::Result.new(sites, counts).operands
    assert_equal expected, actual
  end

  test 'DYTY40', %w(
  | the result lists every possible path of every site, in
  | order, with how many evaluations took it, zero for a
  | path never taken and for every path of a site never run
  ) do
    sites = {
      'k.rb:2:2' => condition('&&', 16...23, 27...35),
      'k.rb:6:4' => condition('||', 57...64, 68...77)
    }
    site_paths = {
      'k.rb:2:2' => { [true, false] => 2, [false, nil] => 1 }
    }
    expected = {
      'k.rb:2:2' => [
        { path: [true, true], count: 0 },
        { path: [true, false], count: 2 },
        { path: [false, nil], count: 1 }
      ],
      'k.rb:6:4' => [
        { path: [true, nil], count: 0 },
        { path: [false, true], count: 0 },
        { path: [false, false], count: 0 }
      ]
    }
    result = PathCoverage::Result.new(sites, {}, site_paths)
    assert_equal expected, result.paths
  end
end
