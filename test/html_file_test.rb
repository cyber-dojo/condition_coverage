require_relative 'test_helper'
require 'condition_coverage/html_file'
require 'rexml/document'

class HtmlFileTest < Id58TestBase
  test 'gae510', %w(
  | a file's listing shows every line's code in order;
  | a line with no condition has a plain number, and a line
  | with one has its number on a button giving its status,
  | closed, and naming the tree it opens
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: '  def self.ok?(id) = !id.empty?',
        status: nil, span: nil },
      { number: 3,
        text: "  def self.kata?(id) = ok?(id) && id.start_with?('N')",
        status: :gaps, span: 3..3 },
      { number: 4, text: 'end', status: nil, span: nil }
    ]
    listing = ConditionCoverage::HtmlFile.listing(lines)
    html = REXML::Document.new(listing)

    codes = html.elements.to_a('//*[@data-src]')
    expected = lines.map { |line| line[:text] }
    actual = codes.map { |element| text_of(element) }
    assert_equal expected, actual

    outside_buttons = '//*[@data-line][not(ancestor::button)]'
    plain = html.elements.to_a(outside_buttons)
    actual = plain.map { |element| text_of(element) }
    assert_equal %w(1 2 4), actual

    button = html.elements.to_a('//button')
    assert_equal 1, button.size
    expected = {
      'data-status' => 'gaps',
      'aria-expanded' => 'false',
      'aria-controls' => 'tree-3'
    }
    attributes = button[0].attributes
    actual = expected.keys.to_h { |name| [name, attributes[name]] }
    assert_equal expected, actual
    assert_equal '3', text_of(button[0])
  end

  test 'gae520', %w(
  | the lines of a condition written over several lines
  | share one button holding all their numbers, which opens
  | the tree named after the first, and their code is
  | still shown line by line
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: '  def self.kata?(id)', status: nil,
        span: nil },
      { number: 3, text: '    ok?(id) &&', status: :gaps,
        span: 3..4 },
      { number: 4, text: "      id.start_with?('N')", status: :gaps,
        span: 3..4 },
      { number: 5, text: '  end', status: nil, span: nil }
    ]
    listing = ConditionCoverage::HtmlFile.listing(lines)
    html = REXML::Document.new(listing)

    buttons = html.elements.to_a('//button')
    assert_equal 1, buttons.size
    numbers = buttons[0].elements.to_a('*[@data-line]')
    actual = numbers.map { |element| text_of(element) }
    assert_equal %w(3 4), actual
    assert_equal 'tree-3', buttons[0].attributes['aria-controls']

    codes = html.elements.to_a('//*[@data-src]')
    expected = lines.map { |line| line[:text] }
    actual = codes.map { |element| text_of(element) }
    assert_equal expected, actual
  end

  test 'gae530', %w(
  | a span's tree is hidden until its button opens it,
  | and sits straight after the span, so it never splits it;
  | it has one row per operand: text, true, false and gap
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2,
        text: "  def self.kata?(id) = ok?(id) && id.start_with?('N')",
        status: :gaps, span: 2..2 },
      { number: 3, text: 'end', status: nil, span: nil }
    ]
    trees = {
      2 => [
        { operator: '&&', operands: [
          { text: 'ok?(id)', truthy: 1, falsy: 1, gap: nil },
          { text: "id.start_with?('N')", truthy: 1, falsy: 0,
            gap: 'never false' }
        ] }
      ]
    }
    listing = ConditionCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)

    tree = html.elements["//*[@id='tree-2']"]
    assert_equal 'hidden', tree.attributes['hidden']
    before = tree.previous_element
    opener = before.elements['.//button'].attributes['aria-controls']
    assert_equal 'tree-2', opener

    rows = tree.elements.to_a('.//*[@data-operand]')
    actual = rows.map do |row|
      %w(text truthy falsy gap).map do |cell|
        text_of(row.elements["*[@data-#{cell}]"])
      end
    end
    expected = [
      ['ok?(id)', '1', '1', ''],
      ["id.start_with?('N')", '1', '0', 'never false']
    ]
    assert_equal expected, actual
  end

  test 'gae535', %w(
  | a tree opens with a heading row, then for each site
  | a row naming its operator, its operands branching below
  ) do
    lines = [
      { number: 1, text: '  ok?(id) && new?(id)', status: :gaps,
        span: 1..1 }
    ]
    trees = {
      1 => [
        { operator: '&&', operands: [
          { text: 'ok?(id)', truthy: 1, falsy: 1, gap: nil },
          { text: 'new?(id)', truthy: 0, falsy: 1, gap: 'never true' }
        ] }
      ]
    }
    listing = ConditionCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    headings = tree.elements.to_a('.//*[@data-heading]/*')
    actual = headings.map { |element| text_of(element) }
    assert_equal %w(condition true false gap), actual

    operator = tree.elements['.//*[@data-operator]']
    assert_equal '&&', text_of(operator)

    branches = tree.elements.to_a('.//*[@data-branch]')
    actual = branches.map { |element| text_of(element) }
    assert_equal ['├─ ', '└─ '], actual
  end

  test 'gae540', %w(
  | a file's page is headed by its path, links back to the
  | index from as deep as the page sits, and holds its listing
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: 'end', status: nil, span: nil }
    ]
    html_file = ConditionCoverage::HtmlFile
    page = html_file.page('source/kata.rb', lines, {})
    html = REXML::Document.new(page)

    assert_equal 'source/kata.rb', text_of(html.elements['//h1'])

    back = html.elements['//a[@data-index]'].attributes['href']
    assert_equal '../../index.html', back

    codes = html.elements.to_a('//*[@data-src]')
    actual = codes.map { |element| text_of(element) }
    assert_equal ['module Kata', 'end'], actual
  end
end
