require_relative 'test_helper'
require 'path_coverage/html_mode'

class HtmlModeTest < Id58TestBase
  test 'Tg9e10', %w(
  | Example: the html element's attribute of a run measuring
  | methods
  | It names the one mode its pages show, within each method,
  | as there is no toggle.
  ) do
    actual = PathCoverage::HtmlMode.attribute(true)
    assert_equal ' data-mode="methods"', actual
  end

  test 'Tg9e11', %w(
  | Example: the html element's attribute of a run not
  | measuring methods
  | Its pages show within each decision, the mode a page with
  | none named shows, so it names none.
  ) do
    assert_equal '', PathCoverage::HtmlMode.attribute(false)
  end
end
