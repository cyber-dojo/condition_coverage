require_relative 'test_helper'
require 'path_coverage/card_tree'

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
      'k.rb:1:0' => {
        '2:2' => { 'parent' => nil, 'in' => nil, 'on' => nil },
        '3:4' => { 'parent' => '2:2', 'in' => 'then', 'on' => [0] },
        '3:14' => { 'parent' => '3:4', 'in' => 'then', 'on' => [0] },
        '3:21' => { 'parent' => '3:4', 'in' => 'else', 'on' => [1] }
      }
    }
    assert_equal expected, PathCoverage::CardTree.of(source, 'k.rb')
  end

  test 'Ct8e02', %w(
  | Example: kept, an && of a and a select's any?, its block a ?:
  | A row inside a leaf of its parent is in no arm, and runs on
  | each of its parent's paths that evaluate that leaf: the ?:
  | runs only where select called its block with an item, not
  | where a was false, nor where select had 0 items.
  ) do
    source = <<~RUBY
      def kept(xs, a)
        a && xs.select { |x| x ? 1 : nil }.any?
      end
    RUBY
    expected = {
      'k.rb:1:0' => {
        '2:2' => { 'parent' => nil, 'in' => nil, 'on' => nil },
        '2:23' => {
          'parent' => '2:2', 'in' => nil, 'on' => (2..11).to_a
        }
      }
    }
    assert_equal expected, PathCoverage::CardTree.of(source, 'k.rb')
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
      'k.rb:1:0' => {
        '2:2' => { 'parent' => nil, 'in' => nil, 'on' => nil },
        '4:4' => { 'parent' => '2:2', 'in' => 'else', 'on' => [1] }
      }
    }
    assert_equal expected, PathCoverage::CardTree.of(source, 'k.rb')
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
      'k.rb:1:0' => {
        '2:2' => { 'parent' => nil, 'in' => nil, 'on' => nil },
        '2:26' => {
          'parent' => '2:2', 'in' => 'then', 'on' => [0, 1]
        }
      }
    }
    assert_equal expected, PathCoverage::CardTree.of(source, 'k.rb')
  end

  test 'Ct8e05', %w(
  | Example: every Ruby file of the gem's lib and test, and of
  | its demo's source
  | Every row placed in a parent is placed in a row of its own
  | card, on some of that parent's possible paths and on none
  | it does not have: no row hangs from nothing, or runs on no
  | path at all.
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

  # The misfits, as misfits gives them, of every card of source,
  # as if it were k.rb.
  def misplaced_in(source)
    sites = PathCoverage::Manifest.sites(source, 'k.rb')
    tree = PathCoverage::CardTree.of(source, 'k.rb', sites)
    tree.values.flat_map do |rows|
      inner = rows.values - [PathCoverage::CardTree::TOP]
      misfits(rows.keys, inner, sites)
    end
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
