require_relative 'test_helper'
require 'condition_coverage/html_file'
require 'rexml/document'

class HtmlFileTest < Id58TestBase
  test 'gae510', %w(
  | a file's listing shows every line's code in order;
  | a line with no condition has a plain number, and a line
  | with one has its number on a button giving its status,
  | closed when covered, and naming the tree it opens
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: '  def self.ok?(id) = !id.empty?',
        status: nil, span: nil },
      { number: 3,
        text: "  def self.kata?(id) = ok?(id) && id.start_with?('N')",
        status: :covered, span: 3..3 },
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
      'data-status' => 'covered',
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
  | a covered span's tree is hidden until its button opens it,
  | and sits straight after the span, so it never splits it;
  | it has one row per operand: text, true, false and gap
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2,
        text: "  def self.kata?(id) = ok?(id) && id.start_with?('N')",
        status: :covered, span: 2..2 },
      { number: 3, text: 'end', status: nil, span: nil }
    ]
    trees = {
      2 => [
        { operator: '&&', operands: [
          { text: 'ok?(id)', truthy: 1, falsy: 1, gap: nil },
          { text: "id.start_with?('N')", truthy: 1, falsy: 1,
            gap: nil }
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
      ["id.start_with?('N')", '1', '1', '']
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

  test 'gae538', %w(
  | a nested condition's operator branches from its parent
  | like an operand, and its own operands branch below it,
  | indented under its branch so the tree reads as one
  ) do
    lines = [
      { number: 1, text: '  ok?(id) && (new?(id) || id.size == 6)',
        status: :gaps, span: 1..1 }
    ]
    either = { operator: '||', operands: [
      { text: 'new?(id)', truthy: 1, falsy: 1, gap: nil },
      { text: 'id.size == 6', truthy: 0, falsy: 1, gap: 'never true' }
    ] }
    trees = {
      1 => [
        { operator: '&&', operands: [
          { text: 'ok?(id)', truthy: 2, falsy: 1, gap: nil },
          either
        ] }
      ]
    }
    listing = ConditionCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    operators = tree.elements.to_a('.//*[@data-operator]')
    actual = operators.map { |element| text_of(element) }
    assert_equal ['&&', '||'], actual

    branches = tree.elements.to_a('.//*[@data-branch]')
    actual = branches.map { |element| text_of(element) }
    expected = ['├─ ', '└─ ', '   ├─ ', '   └─ ']
    assert_equal expected, actual

    texts = tree.elements.to_a('.//*[@data-operand]/*[@data-text]')
    actual = texts.map { |element| text_of(element) }
    assert_equal ['ok?(id)', 'new?(id)', 'id.size == 6'], actual
  end

  test 'gae539', %w(
  | a nested condition that is not the last operand keeps its
  | parent's branch line running down beside its own operands
  ) do
    lines = [
      { number: 1, text: '  (ok?(id) || new?(id)) && id.size == 6',
        status: :covered, span: 1..1 }
    ]
    either = { operator: '||', operands: [
      { text: 'ok?(id)', truthy: 1, falsy: 1, gap: nil },
      { text: 'new?(id)', truthy: 1, falsy: 1, gap: nil }
    ] }
    trees = {
      1 => [
        { operator: '&&', operands: [
          either,
          { text: 'id.size == 6', truthy: 1, falsy: 1, gap: nil }
        ] }
      ]
    }
    listing = ConditionCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    branches = tree.elements.to_a('.//*[@data-branch]')
    actual = branches.map { |element| text_of(element) }
    expected = ['├─ ', '│  ├─ ', '│  └─ ', '└─ ']
    assert_equal expected, actual
  end

  test 'gae536', %w(
  | a button over two or more sites shows how many,
  | and its tree keeps each site's rows in a group of their own,
  | so they can be told apart; a one-site button shows no count
  ) do
    lines = [
      { number: 1, text: '  [ok?(a) && new?(a), ok?(b) && new?(b)]',
        status: :gaps, span: 1..1 },
      { number: 2, text: '  ok?(c) && new?(c)', status: :covered,
        span: 2..2 }
    ]
    site = { operator: '&&', operands: [
      { text: 'ok?(a)', truthy: 1, falsy: 1, gap: nil },
      { text: 'new?(a)', truthy: 1, falsy: 1, gap: nil }
    ] }
    trees = { 1 => [site, site], 2 => [site] }
    listing = ConditionCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)

    counts = html.elements.to_a('//button/*[@data-site-count]')
    actual = counts.map { |element| text_of(element) }
    assert_equal ['2'], actual

    groups = html.elements.to_a("//*[@id='tree-1']/*[@data-site]")
    assert_equal 2, groups.size
  end

  test 'gae532', %w(
  | a site with gaps has its tree open as the page loads,
  | so the gaps show without a click; a covered site's tree
  | stays closed
  ) do
    lines = [
      { number: 1, text: '  ok?(a) && new?(a)', status: :gaps,
        span: 1..1 },
      { number: 2, text: '  ok?(b) && new?(b)', status: :covered,
        span: 2..2 }
    ]
    listing = ConditionCoverage::HtmlFile.listing(lines)
    html = REXML::Document.new(listing)

    buttons = html.elements.to_a('//button')
    actual = buttons.map { |b| b.attributes['aria-expanded'] }
    assert_equal %w(true false), actual

    trees = html.elements.to_a("//*[@class='tree']")
    actual = trees.map { |tree| tree.attributes['hidden'] }
    assert_equal [nil, 'hidden'], actual
  end

  test 'gae534', %w(
  | every row has a cell left of its number, so the numbers
  | stay aligned; at a site with gaps it links to the previous
  | and next site with gaps, wrapping round at either end
  ) do
    lines = [
      { number: 1, text: '  ok?(a) && new?(a)', status: :gaps,
        span: 1..1 },
      { number: 2, text: '  log(a)', status: nil, span: nil },
      { number: 3, text: '  ok?(b) && new?(b)', status: :gaps,
        span: 3..3 },
      { number: 4, text: '  ok?(c) && new?(c)', status: :covered,
        span: 4..4 },
      { number: 5, text: '  ok?(d) && new?(d)', status: :gaps,
        span: 5..5 }
    ]
    listing = ConditionCoverage::HtmlFile.listing(lines)
    html = REXML::Document.new(listing)

    cells = html.elements.to_a('//*[@data-nav]')
    actual = cells.map do |cell|
      %w(prev next).map do |way|
        link = cell.elements["a[@data-#{way}]"]
        link&.attributes&.[]('href')
      end
    end
    expected = [
      ['#L5', '#L3'], [nil, nil], ['#L1', '#L5'], [nil, nil],
      ['#L3', '#L1']
    ]
    assert_equal expected, actual
  end

  test 'gae537', %w(
  | every line number, on a button or not, is the target
  | L<number> that a link to that line names
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: '  ok?(id) && new?(id)', status: :gaps,
        span: 2..2 },
      { number: 3, text: 'end', status: nil, span: nil }
    ]
    listing = ConditionCoverage::HtmlFile.listing(lines)
    html = REXML::Document.new(listing)

    numbers = html.elements.to_a('//*[@data-line]')
    actual = numbers.map { |element| element.attributes['id'] }
    assert_equal %w(L1 L2 L3), actual
  end

  test 'gae545', %w(
  | a file's page opens with one header, sticky in the page,
  | holding the back link, the path, and two lists of links to
  | the first line of each site: those covered, then those
  | with gaps
  ) do
    lines = [
      { number: 1, text: '  ok?(a) && new?(a)', status: :gaps,
        span: 1..1 },
      { number: 2, text: '  ok?(b) && new?(b)', status: :covered,
        span: 2..2 },
      { number: 3, text: '  log(b)', status: nil, span: nil },
      { number: 4, text: '  ok?(c) && new?(c)', status: :gaps,
        span: 4..4 }
    ]
    html_file = ConditionCoverage::HtmlFile
    page = html_file.page('source/kata.rb', lines, {})
    html = REXML::Document.new(page)
    head = html.elements['//*[@data-head]']

    assert_equal 'source/kata.rb', text_of(head.elements['.//h1'])
    refute_nil head.elements['.//a[@data-index]']

    expected = { 'covered' => %w(#L2), 'gaps' => %w(#L1 #L4) }
    actual = expected.keys.to_h do |status|
      links = head.elements.to_a(".//*[@data-jumps='#{status}']/a")
      [status, links.map { |link| link.attributes['href'] }]
    end
    assert_equal expected, actual
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
