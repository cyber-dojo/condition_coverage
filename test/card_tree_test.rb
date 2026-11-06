require_relative 'test_helper'
require 'path_coverage/card_tree'
require 'path_coverage/card_ways'

class CardTreeTest < TidTest
  test 'Ct8e01', %w(
  | Example: pick, an if of a && b holding an if of b
  | Each row of pick's card names its parent, the site whose
  | arm it is in, that arm, and on, the parent's possible paths
  | it runs on, by their index: the inner if runs only on the
  | outer's one path that takes its then arm. A row at the top
  | of the method has none of these.
  ) do
    source = <<~RUBY
      def pick(a, b)
        if a && b
          if b then 1 else 2 end
        end
      end
    RUBY
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '3:4' => ['2:2', 'then', [0], nil, nil],
      '3:14' => ['3:4', 'then', [0], nil, nil],
      '3:21' => ['3:4', 'else', [1], nil, nil]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e02', %w(
  | Example: kept, an && of a and a select's any?, its block a ?:
  | A row inside a leaf of its parent is in no arm, and runs on
  | each of its parent's paths that evaluate that leaf: the ?:
  | runs only where select called its block with an item, not
  | where a was false, nor where select had 0 items.
  | It is the whole of its leaf, select's block, so gives what
  | its paths give it: not known, as neither arm's truthiness
  | is noted.
  ) do
    source = <<~RUBY
      def kept(xs, a)
        a && xs.select { |x| x ? 1 : nil }.any?
      end
    RUBY
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '2:23' => ['2:2', nil, (2..11).to_a, 2, [nil, nil]]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e03', %w(
  | Example: odd, an if of a with an empty then arm, a ?: in its else
  | An arm with no statements holds no row, so the ?: is placed
  | in the else, on the if's false path.
  ) do
    source = <<~RUBY
      def odd(a, b)
        if a
        else
          b ? 1 : 2
        end
      end
    RUBY
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '4:4' => ['2:2', 'else', [1], nil, nil]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e04', %w(
  | Example: each_if, an && of a and a ?: of b whose then arm
  | is an each whose block is a ?: of x
  | A row inside an arm of a condition nested in its parent
  | runs only on the parent's paths that take that arm: the ?:
  | of x runs where a and b were both true, whatever the &&'s
  | value.
  ) do
    source = <<~RUBY
      def each_if(a, b, xs)
        a && (b ? xs.each { |x| x ? 1 : 2 } : 3)
      end
    RUBY
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '2:26' => ['2:2', 'then', [0, 1], 2, nil]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e08', %w(
  | Example: fee, an if holding a ?: of an &&; two, two ?:s one
  | after another; led?, an || of an any? whose block is an &&
  | The ways through a card fold its tree: rows one after
  | another multiply, and a site adds up its paths, each times
  | the ways of the rows it runs on that path; a row that is the
  | whole of a leaf counts only its paths that give the leaf the
  | outcome the path has.
  | fee: then 3, else 1, so 4. two: 2 times 2, so 4. led?: the
  | ||'s true path takes the 2 any? paths giving true, 1 way
  | each; each false path takes its 3 giving false, 1 + 2 + 2.
  ) do
    source = <<~RUBY
      def fee(member, paid, big)
        if member
          paid && big ? 5 : 10
        else
          0
        end
      end
      def two(a, b)
        x = a ? 1 : 2
        y = b ? 3 : 4
        [x, y]
      end
      def led?(xs)
        xs.any? { |x| x.odd? && x > 1 } || xs.empty?
      end
    RUBY
    expected = { 'k.rb:1:0' => 4, 'k.rb:8:0' => 4, 'k.rb:13:0' => 12 }
    assert_equal expected, PathCoverage::CardWays.of(source, 'k.rb')
  end

  test 'Ct8e07', %w(
  | Example: led?, an || of an any? and xs.empty?
  | The || starts where the any?'s receiver, xs, does, yet it is
  | the any?'s parent, not its child: a site is placed where its
  | whole code lies, not just where it starts.
  ) do
    source = <<~RUBY
      def led?(xs)
        xs.any? { |x| x.odd? } || xs.empty?
      end
    RUBY
    gives = [false, true, false, true, false]
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '2:5' => ['2:2', nil, [0, 1, 2], 0, gives],
      '2:16' => ['2:5', nil, [1, 2, 3, 4], 1, nil]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e06', %w(
  | Example: odd?, an && of a and an any?
  | A row in a leaf of its parent names that leaf, by its
  | index. A row that is the whole of that leaf, as the any? is,
  | also names what each of its own possible paths gives the
  | leaf: the any?'s value, false with 0 items, else its last
  | answer. The any?'s block's row is inside a leaf, not all of
  | it, so gives nothing.
  ) do
    source = <<~RUBY
      def odd?(a, xs)
        a && xs.any? { |x| x.odd? }
      end
    RUBY
    gives = [false, true, false, true, false]
    expected = {
      '2:2' => [nil, nil, nil, nil, nil],
      '2:10' => ['2:2', nil, [0, 1], 1, gives],
      '2:21' => ['2:10', nil, [1, 2, 3, 4], 1, nil]
    }
    assert_equal expected, places(source)
  end

  test 'Ct8e05', %w(
  | Example: every Ruby file of the gem's lib and test, and of
  | its demo's source
  | Every row placed in a parent is placed in a row of its own
  | card, on some of that parent's possible paths and on none
  | it does not have: no row hangs from nothing, or runs on no
  | path at all. And no row is its own ancestor: following
  | parents from any row reaches the top.
  ) do
    root = File.expand_path('..', __dir__)
    globs = %w(lib/**/*.rb test/*.rb demo/source/*.rb)
    files = globs.flat_map { Dir.glob(_1, base: root) }.sort
    misplaced = files.to_h do |file|
      [file, misplaced_in(File.read("#{root}/#{file}"))]
    end
    assert_equal files.to_h { [_1, []] }, misplaced
  end

  private

  # [parent, in, on, leaf, gives] of each row of source's one
  # card, its def's on line 1, as if source were k.rb.
  def places(source)
    rows = PathCoverage::CardTree.of(source, 'k.rb')['k.rb:1:0']
    rows.transform_values do |place|
      place.values_at('parent', 'in', 'on', 'leaf', 'gives')
    end
  end

  # The misfits, as misfits gives them, of every card of source,
  # as if it were k.rb.
  def misplaced_in(source)
    sites = PathCoverage::Manifest.sites(source, 'k.rb')
    tree = PathCoverage::CardTree.of(source, 'k.rb', sites)
    tree.values.flat_map do |rows|
      inner = rows.values - [PathCoverage::CardTree::TOP]
      misfits(rows.keys, inner, sites) + looped(rows)
    end
  end

  # The key each row of rows, a card's places, reaches after as
  # many steps up its parents as rows has rows: none, unless some
  # row is its own ancestor, as every other walk reaches the top.
  def looped(rows)
    reached = rows.keys.map do |key|
      rows.size.times.reduce(key) { |at, _| rows.dig(at, 'parent') }
    end
    reached.compact
  end

  # Each parent of inner, the places of a card's rows that have
  # one, that is none of keys, its rows' keys; true for each
  # place on no path; and each path a place is on that its
  # parent, among sites, does not have.
  def misfits(keys, inner, sites)
    parents = inner.map { _1['parent'] } - keys
    empty = inner.map { _1['on'].empty? } - [false]
    beyond = inner.flat_map do |place|
      parent = sites["k.rb:#{place['parent']}"]
      place['on'] - [*0...PathCoverage::SitePaths.possible(parent).size]
    end
    [*parents, *empty, *beyond]
  end
end
