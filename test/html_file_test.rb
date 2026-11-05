require_relative 'test_helper'
require 'path_coverage/html_file'
require 'rexml/document'

class HtmlFileTest < TidTest
  test 'gae510', %w(
  | a file's listing shows every line's code in order;
  | a line with no condition has a plain number, and a line
  | with one outside every method has its number on a loose
  | button giving its status, closed, naming the card it opens
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
      'aria-controls' => 'paths-3'
    }
    attributes = button[0].attributes
    actual = expected.keys.to_h { |name| [name, attributes[name]] }
    assert_equal expected, actual
    assert_equal '3', text_of(button[0])
  end

  test 'gae520', %w(
  | the lines of a condition written over several lines,
  | outside every method, share one button holding all their
  | numbers, which opens the card named after the first, and
  | their code is still shown line by line
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
    assert_equal 'paths-3', buttons[0].attributes['aria-controls']

    codes = html.elements.to_a('//*[@data-src]')
    expected = lines.map { |line| line[:text] }
    actual = codes.map { |element| text_of(element) }
    assert_equal expected, actual
  end

  test 'gae530', %w(
  | Example: the tree of ok?(id) && id.start_with?('N')
  | It has one row per operand: its text, then its outcome on
  | each path, T or F, blank where the path never reached it.
  ) do
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
    tree = tree_of(trees[2])

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
  | operator and for each path 0 or *, whether it was taken,
  | its count on hover, a path never taken marked as a gap;
  | its operands branch below
  ) do
    trees = {
      1 => [
        {
          operator: '&&', counts: [0, 1284, 1],
          cells: [false, true, false],
          operands: [
            { text: 'ok?(id)', cells: [true, true, false] },
            { text: 'new?(id)', cells: [false, true, nil] }
          ]
        }
      ]
    }
    tree = tree_of(trees[1])

    operator = tree.elements['.//*[@data-operator]']
    assert_equal '&&', text_of(operator)

    counts = operator.parent.elements.to_a('*[@data-count]')
    actual = counts.map do |count|
      attributes = count.attributes
      [text_of(count), attributes['class'], attributes['data-hover']]
    end
    expected = [
      ['0', 'count never', '0 times'], ['*', 'count', '1,284 times'],
      ['*', 'count', '1 time']
    ]
    assert_equal expected, actual

    assert_equal %w(ths lhs), branches_of(tree)
  end

  test 'gae538', %w(
  | a nested condition's operator branches from its parent
  | like an operand, and its own operands branch below it,
  | indented under its branch so the tree reads as one
  ) do
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
    tree = tree_of(trees[1])

    operators = tree.elements.to_a('.//*[@data-operator]')
    actual = operators.map { |element| text_of(element) }
    assert_equal ['&&', '||'], actual

    assert_equal %w(ths lhs sssths ssslhs), branches_of(tree)

    texts = tree.elements.to_a('.//*[@data-operand]/*[@data-text]')
    actual = texts.map { |element| text_of(element) }
    assert_equal ['ok?(id)', 'new?(id)', 'id.size == 6'], actual
  end

  test 'gae539', %w(
  | a nested condition that is not the last operand keeps its
  | parent's branch line running down beside its own operands
  ) do
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
    tree = tree_of(trees[1])

    assert_equal %w(ths vssths vsslhs lhs), branches_of(tree)
  end

  test 'gae531', %w(
  | a ternary's arm has a row of its own, ? or : before it: an
  | arm holding a condition is named by its operator, shows
  | its value on each path, and has the condition's operands
  | branching below; a plain arm is named by its text, and
  | marks each path that took it
  ) do
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
    tree = tree_of(trees[1])

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { cell_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    expected = [['? &&', 'F', 'T', ''], [': :no', '', '', 'taken']]
    assert_equal expected, actual

    assert_equal %w(ths ths vssths vsslhs lhs), branches_of(tree)
  end

  test 'gae533', %w(
  | an if's arms are named then and else, as their text is
  | statements, and each marks the paths that took it
  ) do
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
    tree = tree_of(trees[1])

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { cell_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    expected = [
      ['then', '', 'taken', ''],
      ['else', 'taken', '', 'taken']
    ]
    assert_equal expected, actual
  end

  test 'gae547', %w(
  | Example: unless x alpha end
  | The arm's row is labelled then, as for an if.
  ) do
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
    tree = tree_of(trees[1])

    labels = tree.elements.to_a('.//*[@data-arm]/*[@data-label]')
    assert_equal(['then'], labels.map { |label| text_of(label) })
  end

  test 'gae566', %w(
  | Example: if x alpha else beta end, then x ? :a : :b
  | The if's then names its first arm, quoting no code.
  | So its label is marked as a name, to be told apart.
  | Its else, and the ternary's arm labels, quote code, so are not.
  ) do
    arms = lambda do |texts|
      %i[then else].zip(texts, [[true, false], [false, true]])
                   .map do |arm, text, cells|
        { arm:, text:, cells:, body: nil }
      end
    end
    tree = lambda do |operator, texts|
      [{ operator:, counts: [0, 1], cells: [nil, nil],
         operands: [{ text: 'x', cells: [true, false] },
                    *arms.call(texts)] }]
    end
    trees = { 1 => tree.call('if', %w(alpha beta)),
              2 => tree.call('?:', %w(:a :b)) }
    named = lambda do |line|
      labels = tree_of(trees[line]).elements.to_a('.//*[@data-label]')
      labels.map { |label| label.attributes['data-named'] }
    end
    actual = [named.call(1), named.call(2)]
    assert_equal [['', nil], [nil, nil]], actual
  end

  test 'gae567', %w(
  | Example: the tree of ok?(id) && id.size == 6
  | Its operator && is coloured as it is in the code.
  | So is each operand, eg the 6 of id.size == 6.
  ) do
    operands = [
      { text: 'ok?(id)', cells: [true, false] },
      { text: 'id.size == 6', cells: [true, nil] }
    ]
    trees = {
      1 => [{ operator: '&&', counts: [0, 1], cells: [true, false],
              operands: }]
    }
    tree = tree_of(trees[1])
    named = './/span[@data-operator or @data-text]/span[@class]'
    spans = tree.elements.to_a(named)
    coloured = spans.map do |span|
      [span.attributes['class'], text_of(span)]
    end
    assert_equal [%w(o &&), %w(n 6)], coloured
  end

  test 'gae548', %w(
  | Example: case x when 1 then :small else :other end
  | The arms' rows are labelled when and else.
  | The when row shows whether it matched on each path: T F.
  | The else row shows a tick on the path that took it.
  | The when's pattern (1) has a row below it.
  ) do
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
    tree = tree_of(trees[1])

    rows = tree.elements.to_a('.//*[@data-arm]')
    actual = rows.map do |row|
      cells = row.elements.to_a('*[@data-cell]').map { cell_of(_1) }
      [text_of(row.elements['*[@data-label]']), *cells]
    end
    assert_equal [%w(when T F), ['else', '', 'taken']], actual
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
    tree = tree_of(trees[1])

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
    rows = tree_of(trees[1]).elements.to_a('.//*[@data-operand]')
    cells = rows.last.elements.to_a('*[@data-cell]')
    assert_equal(%w(T F TF), cells.map { |cell| text_of(cell) })
  end

  test 'gae536', %w(
  | Example: two lines outside every method, the first holding
  | two sites, the second one
  | A loose button over two or more sites shows how many; a
  | one-site button shows no count.
  ) do
    lines = [
      { number: 1, text: '  [ok?(a) && new?(a), ok?(b) && new?(b)]',
        status: :gaps, span: 1..1 },
      { number: 2, text: '  ok?(c) && new?(c)', status: :covered,
        span: 2..2 }
    ]
    tops = [[1, 'gaps', 2], [2, 'covered', 1]]
    cards = tops.map do |first, status, sites|
      PathCoverage::Card.new(first:, last: first, column: 0, status:,
                             top: true, sites:, html: '')
    end
    listing = PathCoverage::HtmlFile.listing(lines, cards)
    html = REXML::Document.new(listing)
    counts = html.elements.to_a('//button/*[@data-site-count]')
    assert_equal(['2'], counts.map { |element| text_of(element) })
  end

  test 'gae576', %w(
  | Example: a tree of two sites, as a fold draws a button's
  | tree over two sites
  | Each site's rows are in a group of their own, so they can
  | be told apart.
  ) do
    site = {
      operator: '&&', counts: [1], cells: [true],
      operands: [
        { text: 'ok?(a)', cells: [true] },
        { text: 'new?(a)', cells: [true] }
      ]
    }
    groups = tree_of([site, site]).elements.to_a('*[@data-site]')
    assert_equal 2, groups.size
  end

  test 'gae534', %w(
  | Example: four lines each a top card's, with gaps at lines 1,
  | 3 and 5, covered at line 4, and line 2 in none
  | Every row has a gutter left of its number, so the numbers
  | stay aligned. By a card with gaps it links to the previous
  | and next card with gaps, wrapping round at either end; by a
  | covered card, the only one, to itself.
  ) do
    lines = [1, 2, 3, 4, 5].map do |number|
      { number:, text: "  ok?(#{number})", status: nil, span: nil }
    end
    cards = { 1 => 'gaps', 3 => 'gaps', 4 => 'covered', 5 => 'gaps' }
    cards = cards.map do |first, status|
      PathCoverage::Card.new(first:, last: first, column: 0, status:,
                             top: true, sites: 1, html: '')
    end
    listing = PathCoverage::HtmlFile.listing(lines, cards)
    cells = REXML::Document.new(listing).elements.to_a('//*[@data-nav]')
    actual = cells.map do |cell|
      cell.elements.to_a('a').map { |link| link.attributes['href'] }
    end
    expected = [
      %w(#L5 #L3), [], %w(#L1 #L5), %w(#L4 #L4), %w(#L3 #L1)
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
  | Example: module_lines, a top card with gaps at line 1 and a
  | method's card covered at line 3
  | A file's page opens with one header, sticky in the page,
  | holding the back link, the path, and its row of jumps to the
  | first line of each card with gaps.
  ) do
    page = PathCoverage::HtmlFile.page('source/kata.rb', module_lines,
                                       cards_of_module)
    head = REXML::Document.new(page).elements['//*[@data-head]']
    assert_equal 'source/kata.rb', text_of(head.elements['.//h1'])
    refute_nil head.elements['.//a[@data-index]']
    links = head.elements.to_a(".//*[@class='jump-list']/a")
    assert_equal(%w(#L1), links.map { _1.attributes['href'] })
  end

  test 'gae540', %w(
  | a file's page is headed by its path, links back to the
  | index from as deep as the page sits, and holds its listing
  ) do
    lines = [
      { number: 1, text: 'module Kata', status: nil, span: nil },
      { number: 2, text: 'end', status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/kata.rb', lines)
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
  | Its row of jumps has no links.
  ) do
    page = PathCoverage::HtmlFile.page('source/empty.rb', [])
    html = REXML::Document.new(page)
    assert_equal [], html.elements.to_a('//*[@data-line]')
    assert_equal [], jump_links(html)
  end

  test 'gae560', %w(
  | Example: the page of a file holding require 'json' only
  | Its header's top line is the Path coverage title, linking
  | to the index.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines)
    title = '//header/div[@class="top"]/p[@class="title"]/a'
    link = REXML::Document.new(page).elements[title]
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
    page = PathCoverage::HtmlFile.page('source/models/fee.rb', lines)
    link = REXML::Document.new(page).elements['//h1[@class="path"]/a']
    expected = ['source/models/fee.rb',
                '../../../index.html#row-source/models/fee.rb']
    assert_equal expected, [text_of(link), link.attributes['href']]
  end

  test 'gae563', %w(
  | Example: the page of source/json.rb
  | Its header's top line holds, in order, the Path coverage
  | title, the file's path, then the theme button.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines)
    top = REXML::Document.new(page).elements['//header/div[@class="top"]']
    parts = top.elements.to_a.map do |part|
      [part.name, part.attributes['class']]
    end
    expected = [%w(p title), %w(h1 path), %w(button theme)]
    assert_equal expected, parts
  end

  test 'gae564', %w(
  | Example: the page of source/json.rb
  | Its title bar ends with the light and dark theme button.
  | Its script switches the theme as that button is pressed.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines)
    top = REXML::Document.new(page).elements['//div[@class="top"]']
    assert_equal 'button', top.elements.to_a.last.name
    assert_equal 'theme', top.elements.to_a.last.attributes['class']
    script = '// Switches the page between light and dark'
    assert_includes page, script
  end

  test 'gae565', %w(
  | Example: the line def ok? = true # yes, with its tokens
  | Its code holds each token's text in a span of its class.
  | Its code's text is the line's, whole.
  ) do
    lines = [
      { number: 1, text: 'def ok? = true # yes', status: nil,
        span: nil,
        tokens: [[0, 3, 'k'], [10, 14, 'k'], [15, 20, 'c']] }
    ]
    html = REXML::Document.new(PathCoverage::HtmlFile.listing(lines))
    code = html.elements['//*[@data-src]']
    spans = code.elements.to_a('span').map do |span|
      [span.attributes['class'], text_of(span)]
    end
    assert_equal [%w(k def), %w(k true), ['c', '# yes']], spans
    assert_equal 'def ok? = true # yes', text_of(code)
  end

  test 'gae551', %w(
  | Example: a file holding require 'json' only
  | Its one line has no site, so no card.
  | So its row of jumps has no links.
  ) do
    lines = [
      { number: 1, text: "require 'json'", status: nil, span: nil }
    ]
    page = PathCoverage::HtmlFile.page('source/json.rb', lines)
    assert_equal [], jump_links(REXML::Document.new(page))
  end

  test 'gae552', %w(
  | Example: a file of two lines, ok?(a) && new?(a) and
  | ok?(b) && new?(b), each with gaps
  | Each line is a top card of its own.
  | So the row of jumps links to both.
  | Each one's arrows point to the other, wrapping round.
  ) do
    lines = [
      { number: 1, text: 'ok?(a) && new?(a)', status: :gaps,
        span: 1..1 },
      { number: 2, text: 'ok?(b) && new?(b)', status: :gaps,
        span: 2..2 }
    ]
    cards = [1, 2].map do |first|
      PathCoverage::Card.new(first:, last: first, column: 0,
                             status: 'gaps', top: true, sites: 1,
                             html: '')
    end
    page = PathCoverage::HtmlFile.page('source/kata.rb', lines, cards)
    html = REXML::Document.new(page)
    assert_equal %w(#L1 #L2), jump_links(html)

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
    tree = tree_of(trees[1])

    target = tree.elements['.//*[@data-operand]']
    cells = target.elements.to_a('*[@data-cell]').map { text_of(_1) }
    assert_equal %w(T F), cells
    arm = tree.elements['.//*[@data-arm]']
    label = text_of(arm.elements['*[@data-label]'])
    taken = arm.elements.to_a('*[@data-cell]').map { cell_of(_1) }
    assert_equal ['||= key.upcase', ['', 'taken']], [label, taken]
  end

  test 'gae570', %w(
  | Example: X = a ? 1 : 2 on line 1, then module M holding
  | def self.f(a), lines 3 to 5, its body a covered ?:
  | Each line of f's code is marked in its method, with f's
  | status and its def's column, so CSS draws f's stripe; its
  | def line is marked so, its text's length given for its band,
  | and its last line as its end. Lines in no method are plain.
  ) do
    html = REXML::Document.new(listing_of_module)
    srcs = html.elements.to_a('//*[@data-src]').map do |src|
      attributes = src.attributes
      [attributes['class'], attributes['data-method-status'],
       attributes['style']]
    end
    expected = [
      ['src', nil, nil], ['src', nil, nil],
      ['src in-method def-line', 'covered',
       '--def-col: 2; --def-end: 15'],
      ['src in-method', 'covered', '--def-col: 2'],
      ['src in-method method-end', 'covered', '--def-col: 2'],
      ['src', nil, nil]
    ]
    assert_equal expected, srcs
  end

  test 'gae571', %w(
  | Example: X = a ? 1 : 2 on line 1, then module M holding
  | def self.f(a), lines 3 to 5, its body a covered ?:
  | f's def number opens its card: it is marked a def's, with
  | f's status, closed. The rows of f's body, after its def
  | line, start folded under it.
  ) do
    html = REXML::Document.new(listing_of_module)
    number = html.elements["//*[@id='L3']"].attributes
    actual = %w(class data-status aria-expanded).map { number[_1] }
    assert_equal ['lineno mdef', 'covered', 'false'], actual
    folded = (1..6).select do |n|
      row = html.elements["//*[@id='L#{n}']/ancestor::div[1]"]
      row.attributes['class'].split.include?('method-folded')
    end
    assert_equal [4, 5], folded
  end

  test 'gae572', %w(
  | Example: X = a ? 1 : 2 on line 1, then module M holding
  | def self.f(a), lines 3 to 5, its body a covered ?:
  | The gutter by each card's first line links to the cards of
  | its status before and after it, wrapping round: here each
  | card is the only one of its status, so links to itself.
  ) do
    html = REXML::Document.new(listing_of_module)
    arrows = html.elements.to_a('//*[@data-nav]/a').map do |arrow|
      attributes = arrow.attributes
      %w(data-status href aria-label).map { attributes[_1] }
    end
    expected = [
      ['gaps', '#L1', 'Previous card with gaps, line 1'],
      ['gaps', '#L1', 'Next card with gaps, line 1'],
      ['covered', '#L3', 'Previous card covered, line 3'],
      ['covered', '#L3', 'Next card covered, line 3']
    ]
    assert_equal expected, arrows
  end

  test 'gae573', %w(
  | Example: X = a ? 1 : 2 on line 1, then module M holding
  | def self.f(a), lines 3 to 5, its body a covered ?:
  | Line 1's site is in no method, so its button is loose: it
  | opens line 1's top card and wears its status. Line 4's site
  | is f's card's, so its number is plain, opening nothing.
  ) do
    html = REXML::Document.new(listing_of_module)
    buttons = html.elements.to_a('//button').map do |button|
      attributes = button.attributes
      %w(class data-status aria-controls).map { attributes[_1] }
    end
    assert_equal [['lnum loose', 'gaps', 'paths-1']], buttons
    number = html.elements["//*[@id='L4']"]
    assert_equal 'lineno', number.attributes['class']
  end

  test 'gae574', %w(
  | Example: a top card with gaps at line 1, and a method's card
  | covered at line 3
  | The header's one row of jumps, labelled Gaps, links to the
  | first line of each card with gaps, in line order. A file
  | with none keeps the row, marked empty, so the header is the
  | same height.
  ) do
    jumps = PathCoverage::HtmlNav.jumps(cards_of_module)
    list = REXML::Document.new(jumps).elements["//*[@class='jump-list']"]
    label = list.elements["*[@class='jump-label']"]
    assert_equal 'Gaps', text_of(label)
    links = list.elements.to_a('a').map { _1.attributes['href'] }
    assert_equal ['#L1'], links
    assert_nil list.attributes['data-empty']
    none = REXML::Document.new(PathCoverage::HtmlNav.jumps([]))
    empty = none.elements["//*[@class='jump-list']"]
    assert_equal '', empty.attributes['data-empty']
  end

  test 'gae575', %w(
  | Example: a top card at line 1 and a method's card at line 3
  | The page holds both cards, hidden, in the rail beside the
  | code, then the divider that drags the rail's width.
  ) do
    lines = module_lines
    page = PathCoverage::HtmlFile.page('source/m.rb', lines,
                                       cards_of_module)
    html = REXML::Document.new(page)
    box = html.elements["//*[@class='box']"]
    kids = box.elements.to_a('*').map { _1.attributes['class'] }
    assert_equal %w(rail code divider), kids
    rail = box.elements["*[@class='rail']"]
    ids = rail.elements.to_a('*').map { _1.attributes['id'] }
    assert_equal %w(paths-1 paths-3), ids
  end

  test 'gae577', %w(
  | Example: module M holding def outer, lines 2 to 6, with gaps,
  | holding def inner(a), lines 3 to 5, covered, its body a ?:
  | Each line of inner's is in both methods, and wears its
  | innermost's status and def's column. The ?: is a method's,
  | so its number is plain. Every row of outer's body starts
  | folded, inner's def line among them.
  ) do
    lines = [
      { number: 1, text: 'module M', status: nil, span: nil },
      { number: 2, text: '  def self.outer', status: nil, span: nil },
      { number: 3, text: '    def self.inner(a)', status: nil,
        span: nil },
      { number: 4, text: '      a ? 1 : 2', status: :covered,
        span: 4..4 },
      { number: 5, text: '    end', status: nil, span: nil },
      { number: 6, text: '  end', status: nil, span: nil },
      { number: 7, text: 'end', status: nil, span: nil }
    ]
    card = PathCoverage::Card
    cards = [
      card.new(first: 2, last: 6, column: 2, top: false,
               status: 'gaps', sites: nil, html: ''),
      card.new(first: 3, last: 5, column: 4, top: false,
               status: 'covered', sites: nil, html: '')
    ]
    listing = PathCoverage::HtmlFile.listing(lines, cards)
    html = REXML::Document.new(listing)
    srcs = html.elements.to_a('//*[@data-src]')[2..5].map do |src|
      %w(class data-method-status style).map { src.attributes[_1] }
    end
    expected = [
      ['src in-method def-line', 'covered',
       '--def-col: 4; --def-end: 21'],
      ['src in-method', 'covered', '--def-col: 4'],
      ['src in-method method-end', 'covered', '--def-col: 4'],
      ['src in-method method-end', 'gaps', '--def-col: 2']
    ]
    assert_equal expected, srcs
    assert_equal [], html.elements.to_a('//button')
    folded = "//*[contains(@class, 'method-folded')]"
    rows = html.elements.to_a(folded)
    numbers = rows.map { text_of(_1.elements['*[@data-line]']) }
    assert_equal %w(3 4 5 6), numbers
  end

  test 'gae578', %w(
  | Example: module M holding def a, lines 2 to 3, then def b(x),
  | lines 4 to 6, its body a ?:, then Y = y ? 1 : 2 on line 8
  | The ?: in b, the second method, is a method's, not loose:
  | its number is plain, with no button. Y's ?: is in neither,
  | so it is loose, with the one button.
  ) do
    lines = [
      { number: 1, text: 'module M', status: nil, span: nil },
      { number: 2, text: '  def self.a', status: nil, span: nil },
      { number: 3, text: '  end', status: nil, span: nil },
      { number: 4, text: '  def self.b(x)', status: nil, span: nil },
      { number: 5, text: '    x ? 1 : 2', status: :gaps, span: 5..5 },
      { number: 6, text: '  end', status: nil, span: nil },
      { number: 7, text: 'end', status: nil, span: nil },
      { number: 8, text: 'Y = y ? 1 : 2', status: :gaps, span: 8..8 }
    ]
    cards = [[2, 3], [4, 6]].map do |first, last|
      PathCoverage::Card.new(first:, last:, column: 2, top: false,
                             status: 'gaps', sites: nil, html: '')
    end
    listing = PathCoverage::HtmlFile.listing(lines, cards)
    html = REXML::Document.new(listing)
    opens = html.elements.to_a('//button').map do |button|
      button.attributes['aria-controls']
    end
    assert_equal ['paths-8'], opens
    number = html.elements["//*[@id='L5']"]
    assert_equal 'lineno', number.attributes['class']
  end

  private

  # The lines of X = a ? 1 : 2 on line 1, then module M holding
  # def self.f(a), lines 3 to 5, its body a ?: on line 4.
  def module_lines
    [
      { number: 1, text: 'X = a ? 1 : 2', status: :gaps, span: 1..1 },
      { number: 2, text: 'module M', status: nil, span: nil },
      { number: 3, text: '  def self.f(a)', status: nil, span: nil },
      { number: 4, text: '    a ? 1 : 2', status: :covered,
        span: 4..4 },
      { number: 5, text: '  end', status: nil, span: nil },
      { number: 6, text: 'end', status: nil, span: nil }
    ]
  end

  # The cards of module_lines: a top card with gaps at line 1, and
  # f's covered, lines 3 to 5 at column 2.
  def cards_of_module
    grid = ->(n) { %(<div class="pathgrid" id="paths-#{n}"/>) }
    card = PathCoverage::Card
    [
      card.new(first: 1, last: 1, column: 0, top: true,
               status: 'gaps', sites: 1, html: grid.call(1)),
      card.new(first: 3, last: 5, column: 2, top: false,
               status: 'covered', sites: nil, html: grid.call(3))
    ]
  end

  # The parsed tree of sites, as SiteTree.of gives each, drawn as
  # a fold in a card draws it: each site's rows in a group of
  # their own.
  def tree_of(sites)
    groups = sites.map do |site|
      rows = PathCoverage::HtmlTree.site_rows(site).join
      %(<div class="site" data-site="">#{rows}</div>)
    end
    fold = %(<div class="fold">#{groups.join}</div>)
    REXML::Document.new(fold).root
  end

  # The listing of module_lines with its cards.
  def listing_of_module
    PathCoverage::HtmlFile.listing(module_lines, cards_of_module)
  end

  # Example: a tee then a dash then a space gives ths.
  # The kinds of each branch's cells in tree, in order, one
  # letter a cell: t tee, l ell, v bar, h dash, s space.
  def branches_of(tree)
    tree.elements.to_a('.//*[@data-branch]').map do |branch|
      cells = branch.elements.to_a('*[@data-bx]')
      cells.map { |cell| cell.attributes['data-bx'] }.join
    end
  end

  # The hrefs of the header's row of jumps, to each card with
  # gaps.
  def jump_links(html)
    links = html.elements.to_a("//*[@class='jump-list']/a")
    links.map { |link| link.attributes['href'] }
  end
end
