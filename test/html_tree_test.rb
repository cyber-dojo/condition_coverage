require_relative 'test_helper'
require 'path_coverage/html_tree'
require 'rexml/document'

class HtmlTreeTest < Id58TestBase
  test 'c4e7a9', %w(
  | Example: owner at the end of user&.account&.owner
  | owner is no leaf, as it decides no path, so it has no true
  | or false.
  | Its row ticks each path that called it, and leaves the
  | others blank.
  ) do
    owner = { text: 'owner', called: true, cells: [true, false] }
    row = PathCoverage::HtmlTree.operand_row(owner, '└─ ')
    html = REXML::Document.new(row)
    cells = html.elements.to_a('//*[@data-cell]').map { text_of(_1) }
    tick = [0x2713].pack('U')
    assert_equal [tick, ''], cells
  end
end
