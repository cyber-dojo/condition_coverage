require_relative 'test_helper'
require 'path_coverage/html_mode'
require 'rexml/document'

class HtmlModeTest < Id58TestBase
  test 'Tg9e10', %w(
  | Example: the toggle of a run measuring methods
  | It has two buttons, one for each mode.
  | Within each decision comes first, and is pressed.
  | Within each method comes second.
  | Each names its mode in data-mode.
  ) do
    toggle = PathCoverage::HtmlMode.toggle(true)
    html = REXML::Document.new(toggle)
    buttons = html.elements.to_a('//button').map do |button|
      attributes = button.attributes
      [attributes['data-mode'], attributes['aria-pressed'],
       text_of(button)]
    end
    expected = [
      ['decisions', 'true', 'Within each decision'],
      ['methods', 'false', 'Within each method']
    ]
    assert_equal expected, buttons
  end

  test 'Tg9e11', %w(
  | Example: the toggle of a run not measuring methods
  | There is one mode only, so there is nothing to toggle.
  | So there is no toggle.
  ) do
    assert_equal '', PathCoverage::HtmlMode.toggle(false)
  end
end
