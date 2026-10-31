require_relative 'test_helper'
require 'condition_coverage'

class VersionTest < Id58TestBase
  test 'W3kU10', %w(
  | requiring the gem's entry point defines its version
  ) do
    assert_equal '0.0.1', ConditionCoverage::VERSION
  end
end
