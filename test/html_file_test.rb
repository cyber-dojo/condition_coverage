require_relative 'test_helper'
require 'path_coverage/html_file'
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
    listing = PathCoverage::HtmlFile.listing(lines)
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
    listing = PathCoverage::HtmlFile.listing(lines)
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
  | it has one row per operand: its text, then its outcome on
  | each path, T or F, blank where the path never reached it
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
        {
          operator: '&&', counts: [1, 1, 1],
          cells: [true, false, false],
          operands: [
            { text: 'ok?(id)', cells: [true, true, false] },
            { text: "id.start_with?('N')", cells: [true, false, nil] }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)

    tree = html.elements["//*[@id='tree-2']"]
    assert_equal 'hidden', tree.attributes['hidden']
    before = tree.previous_element
    opener = before.elements['.//button'].attributes['aria-controls']
    assert_equal 'tree-2', opener

    rows = tree.elements.to_a('.//*[@data-operand]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { text_of(_1) }
      [text_of(row.elements['*[@data-text]']), *cells]
    end
    expected = [
      ['ok?(id)', 'T', 'T', 'F'],
      ["id.start_with?('N')", 'T', 'F', '']
    ]
    assert_equal expected, actual
  end

  test 'gae535', %w(
  | a tree opens, for each site, with a row naming its
  | operator and each path's count, a path never taken marked
  | as a gap; its operands branch below
  ) do
    lines = [
      { number: 1, text: '  ok?(id) && new?(id)', status: :gaps,
        span: 1..1 }
    ]
    trees = {
      1 => [
        {
          operator: '&&', counts: [0, 2, 1],
          cells: [false, true, false],
          operands: [
            { text: 'ok?(id)', cells: [true, true, false] },
            { text: 'new?(id)', cells: [false, true, nil] }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    operator = tree.elements['.//*[@data-operator]']
    assert_equal '&&', text_of(operator)

    counts = operator.parent.elements.to_a('*[@data-count]')
    actual = counts.map { [text_of(_1), _1.attributes['class']] }
    expected = [['0', 'count never'], %w(2 count), %w(1 count)]
    assert_equal expected, actual

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
    either = {
      operator: '||', cells: [true, false],
      operands: [
        { text: 'new?(id)', cells: [true, false] },
        { text: 'id.size == 6', cells: [nil, false] }
      ]
    }
    trees = {
      1 => [
        {
          operator: '&&', counts: [2, 1], cells: [true, false],
          operands: [
            { text: 'ok?(id)', cells: [true, true] },
            either
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
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
    either = {
      operator: '||', cells: [true, true],
      operands: [
        { text: 'ok?(id)', cells: [true, false] },
        { text: 'new?(id)', cells: [nil, true] }
      ]
    }
    trees = {
      1 => [
        {
          operator: '&&', counts: [1, 1], cells: [true, true],
          operands: [
            either,
            { text: 'id.size == 6', cells: [true, true] }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    branches = tree.elements.to_a('.//*[@data-branch]')
    actual = branches.map { |element| text_of(element) }
    expected = ['├─ ', '│  ├─ ', '│  └─ ', '└─ ']
    assert_equal expected, actual
  end

  test 'gae531', %w(
  | a ternary's arm has a row of its own, ? or : before it: an
  | arm holding a condition is named by its operator, shows
  | its value on each path, and has the condition's operands
  | branching below; a plain arm is named by its text, and
  | marks each path that took it
  ) do
    lines = [
      { number: 1, text: '  ok?(id) ? new?(id) && id.size == 6 : :no',
        status: :gaps, span: 1..1 }
    ]
    both = {
      operator: '&&', cells: [false, true, nil],
      operands: [
        { text: 'new?(id)', cells: [true, true, nil] },
        { text: 'id.size == 6', cells: [false, true, nil] }
      ]
    }
    trees = {
      1 => [
        {
          operator: '?:', counts: [0, 1, 2],
          cells: [false, true, nil],
          operands: [
            { text: 'ok?(id)', cells: [true, true, false] },
            {
              arm: :then, text: 'new?(id) && id.size == 6',
              cells: [true, true, false], body: both
            },
            {
              arm: :else, text: ':no',
              cells: [false, false, true], body: nil
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { text_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    tick = [0x2713].pack('U')
    expected = [['? &&', 'F', 'T', ''], [': :no', '', '', tick]]
    assert_equal expected, actual

    branches = tree.elements.to_a('.//*[@data-branch]')
    actual = branches.map { |element| text_of(element) }
    expected = ['├─ ', '├─ ', '│  ├─ ', '│  └─ ', '└─ ']
    assert_equal expected, actual
  end

  test 'gae533', %w(
  | an if's arms are named then and else, as their text is
  | statements, and each marks the paths that took it
  ) do
    lines = [
      { number: 1, text: '  if x == a && y == b', status: :gaps,
        span: 1..1 }
    ]
    both = {
      operator: '&&', cells: [false, true, false],
      operands: [
        { text: 'x == a', cells: [true, true, false] },
        { text: 'y == b', cells: [false, true, nil] }
      ]
    }
    trees = {
      1 => [
        {
          operator: 'if', counts: [0, 1, 2],
          cells: [nil, nil, nil],
          operands: [
            both,
            {
              arm: :then, text: 'alpha',
              cells: [false, true, false], body: nil
            },
            {
              arm: :else, text: 'beta',
              cells: [true, false, true], body: nil
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { text_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    tick = [0x2713].pack('U')
    expected = [
      ['then', '', tick, ''],
      ['else', tick, '', tick]
    ]
    assert_equal expected, actual
  end

  test 'gae547', %w(
  | Example: unless x alpha end
  | The arm's row is labelled then, as for an if.
  ) do
    lines = [
      { number: 1, text: '  unless x', status: :gaps, span: 1..1 }
    ]
    trees = {
      1 => [
        {
          operator: 'unless', counts: [0, 1], cells: [nil, nil],
          operands: [
            { text: 'x', cells: [false, true] },
            {
              arm: :then, text: 'alpha',
              cells: [true, false], body: nil
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    labels = tree.elements.to_a('.//*[@data-arm]/*[@data-label]')
    assert_equal(['then'], labels.map { |label| text_of(label) })
  end

  test 'gae548', %w(
  | Example: case x when 1 then :small else :other end
  | The arms' rows are labelled when and else.
  | The when row shows whether it matched on each path: T F.
  | The else row shows a tick on the path that took it.
  | The when's pattern (1) has a row below it.
  ) do
    lines = [
      { number: 1, text: '  case x', status: :gaps, span: 1..1 }
    ]
    small = {
      operator: 'when', cells: [true, false],
      operands: [{ text: '1', cells: [true, false] }]
    }
    trees = {
      1 => [
        {
          operator: 'case', counts: [0, 1], cells: [nil, nil],
          operands: [
            {
              arm: :when, text: ':small',
              cells: [true, false], body: small
            },
            {
              arm: :else, text: ':other',
              cells: [false, true], body: nil
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { text_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    tick = [0x2713].pack('U')
    assert_equal [%w(when T F), ['else', '', tick]], actual
    texts = tree.elements.to_a('.//*[@data-operand]/*[@data-text]')
    assert_equal(['1'], texts.map { |text| text_of(text) })
  end

  test 'gae549', %w(
  | Example: ids.any? { |id| id.ok? }
  | The ids row shows how many items the block was called
  | with on each path: 0, 1, or * for two or more.
  | The id.ok? row shows its last answer: T or F.
  | It is blank where the block was never called.
  ) do
    lines = [
      { number: 1, text: '  ids.any? { |id| id.ok? }', status: :gaps,
        span: 1..1 }
    ]
    trees = {
      1 => [
        {
          operator: 'any?', counts: [0, 1, 2],
          cells: [nil, true, false],
          operands: [
            { text: 'ids', cells: ['0 items', '1 item', '2+ items'] },
            { text: 'id.ok?', cells: [nil, true, false] }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    rows = tree.elements.to_a('.//*[@data-operand]')
    actual = rows.map do |row|
      row.elements.to_a('*[@data-cell]').map { text_of(_1) }
    end
    assert_equal [%w(0 1 *), ['', 'T', 'F']], actual
  end

  test 'gae54a', %w(
  | Example: ids.select { |id| id.ok? }
  | select calls its block with every item.
  | The id.ok? row shows its answers on each path.
  | T when all were true.
  | F when all were false.
  | TF when both.
  ) do
    lines = [
      { number: 1, text: '  ids.select { |id| id.ok? }',
        status: :gaps, span: 1..1 }
    ]
    trees = {
      1 => [
        {
          operator: 'select', counts: [0, 1, 2],
          cells: [nil, nil, nil],
          operands: [
            {
              text: 'ids', cells: ['1 item', '2+ items', '2+ items']
            },
            {
              text: 'id.ok?', cells: ['all true', 'all false', 'both']
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    rows = html.elements.to_a("//*[@id='tree-1']//*[@data-operand]")
    cells = rows.last.elements.to_a('*[@data-cell]')
    assert_equal(%w(T F TF), cells.map { |cell| text_of(cell) })
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
    site = {
      operator: '&&', counts: [1], cells: [true],
      operands: [
        { text: 'ok?(a)', cells: [true] },
        { text: 'new?(a)', cells: [true] }
      ]
    }
    trees = { 1 => [site, site], 2 => [site] }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
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
    listing = PathCoverage::HtmlFile.listing(lines)
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
    listing = PathCoverage::HtmlFile.listing(lines)
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
    listing = PathCoverage::HtmlFile.listing(lines)
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
    html_file = PathCoverage::HtmlFile
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
    html_file = PathCoverage::HtmlFile
    page = html_file.page('source/kata.rb', lines, {})
    html = REXML::Document.new(page)

    assert_equal 'source/kata.rb', text_of(html.elements['//h1'])

    back = html.elements['//a[@data-index]'].attributes['href']
    assert_equal '../../index.html', back

    codes = html.elements.to_a('//*[@data-src]')
    actual = codes.map { |element| text_of(element) }
    assert_equal ['module Kata', 'end'], actual
  end

  test 'gae550', %w(
  | Example: an empty file
  | Its page has no lines.
  | Its covered and gaps lists have no links.
  ) do
    page = PathCoverage::HtmlFile.page('source/empty.rb', [], {})
    html = REXML::Document.new(page)
    assert_equal [], html.elements.to_a('//*[@data-line]')
    assert_equal({ 'covered' => [], 'gaps' => [] }, jumps_of(html))
  end

  test 'gae560', %w(
  | Example: the page of a file holding require 'json' only, in
  | runs measuring methods, and not
  | Its header's top line is the Path coverage title, linking
  | to the index.
  | Measuring methods, the mode toggle is on that line too.
  | Not measuring methods, there is one mode only, so no toggle.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    top = '//header/div[@class="top"]'
    html_of = lambda do |methods|
      page = PathCoverage::HtmlFile.page('source/json.rb', lines, {},
                                         methods:)
      REXML::Document.new(page)
    end
    modes = lambda do |methods|
      html = html_of.call(methods)
      html.elements.to_a("#{top}/nav[@class=\"modes\"]").size
    end
    assert_equal [1, 0], [modes.call(true), modes.call(false)]
    link = html_of.call(true).elements["#{top}/p[@class=\"title\"]/a"]
    actual = [text_of(link), link.attributes['href']]
    assert_equal ['Path coverage', '../../index.html'], actual
  end

  test 'gae562', %w(
  | Example: the page of source/models/fee.rb
  | Its path heading links back to its own row on the index.
  | So the index opens with that row scrolled into view.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/models/fee.rb',
                                       lines, {})
    link = REXML::Document.new(page).elements['//h1[@class="path"]/a']
    expected = ['source/models/fee.rb',
                '../../../index.html#row-source/models/fee.rb']
    assert_equal expected, [text_of(link), link.attributes['href']]
  end

  test 'gae563', %w(
  | Example: the page of source/json.rb, in a run measuring
  | methods
  | Its header's top line holds, in order, the Path coverage
  | title, the mode toggle, then the file's path.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines, {},
                                       methods: true)
    top = REXML::Document.new(page).elements['//header/div[@class="top"]']
    parts = top.elements.to_a.map do |part|
      [part.name, part.attributes['class']]
    end
    expected = [%w(p title), %w(nav modes), %w(h1 path)]
    assert_equal expected, parts
  end

  test 'gae561', %w(
  | Example: the page of a file holding require 'json' only, in
  | a run measuring methods
  | Its script switches the mode as its toggle is pressed.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines, {},
                                       methods: true)
    assert_includes page, '// Shows the paths of one mode only'
  end

  test 'gae551', %w(
  | Example: a file holding require 'json' only
  | Its one line has no site.
  | So its covered and gaps lists have no links.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines, {})
    html = REXML::Document.new(page)
    assert_equal({ 'covered' => [], 'gaps' => [] }, jumps_of(html))
  end

  test 'gae552', %w(
  | Example: a file of two lines, ok?(a) && new?(a) and
  | ok?(b) && new?(b), each with gaps
  | Each line starts a span of its own.
  | So the gaps list links to both.
  | Each one's arrows point to the other, wrapping round.
  ) do
    lines = [
      { number: 1, text: 'ok?(a) && new?(a)', status: :gaps,
        span: 1..1 },
      { number: 2, text: 'ok?(b) && new?(b)', status: :gaps,
        span: 2..2 }
    ]
    page = PathCoverage::HtmlFile.page('source/kata.rb', lines, {})
    html = REXML::Document.new(page)
    expected = { 'covered' => [], 'gaps' => %w(#L1 #L2) }
    assert_equal expected, jumps_of(html)

    cells = html.elements.to_a('//*[@data-nav]')
    actual = cells.map do |cell|
      %w(prev next).map do |way|
        cell.elements["a[@data-#{way}]"].attributes['href']
      end
    end
    assert_equal [%w(#L2 #L2), %w(#L1 #L1)], actual
  end

  test 'gae553', %w(
  | Example: store[key] ||= key.upcase, its target true on one
  | path and false on the other
  | The target, store[key], has a row showing T then F.
  | The right side's row is labelled ||= key.upcase.
  | It marks the path that ran it, the target false.
  ) do
    lines = [
      { number: 1, text: '  store[key] ||= key.upcase',
        status: :covered, span: 1..1 }
    ]
    trees = {
      1 => [
        {
          operator: '||=', counts: [1, 1], cells: [nil, nil],
          operands: [
            { text: 'store[key]', cells: [true, false] },
            {
              arm: :then, text: 'key.upcase',
              cells: [false, true], body: nil
            }
          ]
        }
      ]
    }
    listing = PathCoverage::HtmlFile.listing(lines, trees)
    html = REXML::Document.new(listing)
    tree = html.elements["//*[@id='tree-1']"]

    target = tree.elements['.//*[@data-operand]']
    cells = target.elements.to_a('*[@data-cell]').map { text_of(_1) }
    assert_equal %w(T F), cells
    arm = tree.elements['.//*[@data-arm]']
    label = text_of(arm.elements['*[@data-label]'])
    taken = arm.elements.to_a('*[@data-cell]').map { text_of(_1) }
    tick = [0x2713].pack('U')
    assert_equal ['||= key.upcase', ['', tick]], [label, taken]
  end

  private

  # { status => hrefs } of the header's covered and gaps lists.
  def jumps_of(html)
    %w(covered gaps).to_h do |status|
      links = html.elements.to_a("//*[@data-jumps='#{status}']/a")
      [status, links.map { |link| link.attributes['href'] }]
    end
  end
end
