require_relative 'test_helper'
require 'path_coverage/method_statements'

class MethodStatementsTest < Id58TestBase
  test 'St3e01', %w(
  | Example: total, a write, a call chain and a value as its
  | top-level statements
  | Each statement is a row: its line, its column and its
  | top, what it is as written.
  | A write is =, a call is (), and a variable read is a value.
  ) do
    source = <<~RUBY
      def total(order)
        sum = order.subtotal
        order.items.first.save
        sum
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    expected = [[2, 2, '='], [3, 2, '()'], [4, 2, 'value']]
    assert_equal expected, rows
  end

  test 'St3e02', %w(
  | Example: refuse, logging then raising, and first,
  | returning its items' first
  | A raise is named raise, not (), though it is a call,
  | as it leaves the method.
  | A return is named return.
  ) do
    source = <<~RUBY
      def refuse(order)
        order.log('refused')
        raise ArgumentError, 'refused'
      end

      def first(items)
        return items.first
      end
    RUBY
    tops = statements(source).transform_values do |rows|
      rows.map(&:top)
    end
    expected = {
      'k.rb:1:0' => ['()', 'raise'], 'k.rb:6:0' => ['return']
    }
    assert_equal expected, tops
  end

  test 'St3e03', %w(
  | Example: a class with an empty initialize
  | initialize has no statements, so no rows.
  ) do
    source = <<~RUBY
      class Feed
        def initialize; end
      end
    RUBY
    assert_equal({ 'k.rb:2:2' => [] }, statements(source))
  end

  test 'St3e04', %w(
  | Example: ship, an if statement then a value
  | The if is a site, so its row is named by its operator,
  | if, as decision mode names it.
  ) do
    source = <<~RUBY
      def ship(order)
        if order.paid?
          order.pack
        end
        order
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    assert_equal [[2, 2, 'if'], [5, 2, 'value']], rows
  end

  test 'St3e05', %w(
  | Example: label, writing a ternary's value then returning it
  | A write is looked through, so its row is the ternary's:
  | named ?: and at the ternary's column, as decision mode
  | names it, not at the write's.
  ) do
    source = <<~RUBY
      def label(items)
        text = items.empty? ? 'none' : 'some'
        text
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    assert_equal [[2, 9, '?:'], [3, 2, 'value']], rows
  end

  test 'St3e06', %w(
  | Example: discount, adding two ternaries' values
  | + imposes no flow, so it is looked through, as is the
  | write and each parenthesis, giving a row for each
  | ternary, in the order they run.
  ) do
    source = <<~RUBY
      def discount(big, member)
        total = (big ? 10 : 0) + (member ? 5 : 0)
        total
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    expected = [[2, 11, '?:'], [2, 28, '?:'], [3, 2, 'value']]
    assert_equal expected, rows
  end

  test 'St3e07', %w(
  | Example: price, returning 0 if free, else its cost
  | A modifier if is a site named at its if keyword, after
  | the statement it guards, so its row is there too.
  ) do
    source = <<~RUBY
      def price(item)
        return 0 if item.free?
        item.cost
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    assert_equal [[2, 11, 'if'], [3, 2, '()']], rows
  end

  test 'St3e08', %w(
  | Example: ship, writing an and chain, an if, then a value
  | A site's row has as many paths as decision mode gives
  | the site: an and of two operands 3, an if 2.
  | Any other row has 1.
  ) do
    source = <<~RUBY
      def ship(order)
        ready = order.paid? && order.packed?
        if ready
          order.send_off
        end
        order
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.top, row.paths]
    end
    assert_equal [['&&', 3], ['if', 2], ['value', 1]], rows
  end

  test 'St3e09', %w(
  | Example: fee, a write, four ifs, then a value
  | Its size is the sum of its rows' paths,
  | 1+2+2+2+2+1 = 10, the paths its tests are to take.
  | Its complexity is their product, 1*2*2*2*2*1 = 16, as its
  | rows run in sequence, each path of one going on to each
  | of the next.
  ) do
    source = <<~RUBY
      def fee(user, order)
        total = order.total
        total -= 5 if user.member?
        total -= 10 if order.big?
        total += 3 if order.express?
        total += 1 if order.gift?
        total
      end
    RUBY
    rows = statements(source)['k.rb:1:0']
    assert_equal [10, 16], [
      PathCoverage::MethodStatements.size(rows),
      PathCoverage::MethodStatements.complexity(rows)
    ]
  end

  test 'St3e10', %w(
  | Example: ship, an if then a value, its if's then taken
  | twice and its else never
  | A site's row names its site, so its taken is how many
  | of the site's paths were taken, 1 of 2 here.
  | Any other row names no site, and its taken is nil, not
  | known, as only sites' paths are recorded.
  ) do
    source = <<~RUBY
      def ship(order)
        if order.paid?
          order.pack
        end
        order
      end
    RUBY
    rows = statements(source)['k.rb:1:0']
    paths = {
      'k.rb:2:2' => [
        { path: [true], count: 2 }, { path: [false], count: 0 }
      ]
    }
    assert_equal ['k.rb:2:2', nil], rows.map(&:site)
    taken = PathCoverage::MethodStatements.taken(rows, paths)
    assert_equal [1, nil], taken
  end

  test 'St3e11', %w(
  | Example: labels, mapping its items through an if
  | A block's body runs once for each item, so it is a
  | context of its own: it is not looked through, and the
  | if inside it is no row of labels. The map is a call.
  ) do
    source = <<~RUBY
      def labels(items)
        items.map do |item|
          if item[:sale]
            'sale'
          else
            'full price'
          end
        end
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    assert_equal [[2, 2, '()']], rows
  end

  test 'St3e12', %w(
  | Example: load, reading a file, rescuing a missing one
  | A def with a rescue has its statements before the rescue
  | as its rows.
  | Its rescue's are none of them, as a rescue runs only when
  | a statement raises.
  ) do
    source = <<~RUBY
      def load(path)
        text = File.read(path)
        JSON.parse(text)
      rescue Errno::ENOENT
        {}
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.line, row.column, row.top]
    end
    assert_equal [[2, 2, '='], [3, 2, '()']], rows
  end

  test 'St3e13', %w(
  | Example: record, writing an index, an attribute, an
  | instance variable, an op-write, then a &. attribute
  | Each write is =, though Ruby makes an index or attribute
  | write a call, eg of []=, as it is no site.
  | A &. write is a site, its call skipped when its receiver
  | is nil, so its row is the site's: &., with 2 paths.
  ) do
    source = <<~RUBY
      def record(event, index, owner)
        event['index'] = index
        event.time = Time.now
        @count = index
        @count += 1
        owner&.last = event
      end
    RUBY
    rows = statements(source)['k.rb:1:0'].map do |row|
      [row.top, row.paths]
    end
    expected = [['=', 1], ['=', 1], ['=', 1], ['=', 1], ['&.', 2]]
    assert_equal expected, rows
  end

  test 'St3e14', %w(
  | Example: a class with initialize and ship
  | Each def's name, by its site, for its card's title.
  ) do
    source = <<~RUBY
      class Shop
        def initialize; end

        def ship(order) = order.pack
      end
    RUBY
    names = PathCoverage::MethodStatements.names(source, 'k.rb')
    expected = { 'k.rb:2:2' => :initialize, 'k.rb:4:2' => :ship }
    assert_equal expected, names
  end

  test 'St3e15', %w(
  | Example: ship, a write, an if, then a value
  | Each row that is no site is reached where its statement
  | starts, named by that place, so a call there can count
  | its runs. The if is a site, its paths already counted.
  ) do
    source = <<~RUBY
      def ship(order)
        box = order.pack
        box.seal if order.fragile?
        box
      end
    RUBY
    reaches = PathCoverage::MethodStatements.reaches(source, 'k.rb')
    assert_equal({ 'k.rb:2:2' => 18, 'k.rb:4:2' => 66 }, reaches)
  end

  test 'St3e16', %w(
  | Example: zero, an endless def of 0
  | An endless def's body is one expression, so a reach call
  | put before it would end the def. Its row is reached by its
  | byte range instead, for the call and it to be wrapped
  | together.
  ) do
    source = <<~RUBY
      def zero = 0
    RUBY
    reaches = PathCoverage::MethodStatements.reaches(source, 'k.rb')
    assert_equal({ 'k.rb:1:11' => 11...12 }, reaches)
  end

  test 'St3e17', %w(
  | Example: ship, a write, an if, then a value, the write
  | reached twice, the value never, the if's then taken
  | Each row is named by where it is.
  | A row that is no site has 1 path, taken when its
  | statement was reached, so the write's taken is 1 and the
  | value's 0.
  ) do
    source = <<~RUBY
      def ship(order)
        box = order.pack
        box.seal if order.fragile?
        box
      end
    RUBY
    rows = statements(source)['k.rb:1:0']
    paths = {
      'k.rb:3:11' => [
        { path: [true], count: 2 }, { path: [false], count: 0 }
      ]
    }
    names = %w(k.rb:2:2 k.rb:3:11 k.rb:4:2)
    assert_equal names, rows.map(&:name)
    reached = { 'k.rb:2:2' => 2 }
    taken = PathCoverage::MethodStatements.taken(rows, paths, reached)
    assert_equal [1, 1, 0], taken
  end

  test 'St3e18', %w(
  | Example: ship, a write, an if, then a value, the write
  | reached, the if's then taken, the value never reached
  | Its card's total is [taken, size]: [2, 4].
  | Without reaches, its write and value are not known, so
  | they count as not taken: [1, 4], never more than it ran.
  ) do
    source = <<~RUBY
      def ship(order)
        box = order.pack
        box.seal if order.fragile?
        box
      end
    RUBY
    paths = {
      'k.rb:3:11' => [
        { path: [true], count: 2 }, { path: [false], count: 0 }
      ]
    }
    statements = PathCoverage::MethodStatements
    totals = [{ 'k.rb:2:2' => 1 }, nil].map do |reached|
      statements.totals(source, 'k.rb', paths, reached)
    end
    expected = [{ 'k.rb:1:0' => [2, 4] }, { 'k.rb:1:0' => [1, 4] }]
    assert_equal expected, totals
  end

  test 'St3e19', %w(
  | Example: ship, logging with a call of its own, then a value
  | A call with no receiver that is no raise, eg log, is a
  | call: ().
  ) do
    source = <<~RUBY
      def ship(order)
        log('shipped')
        order
      end
    RUBY
    tops = statements(source)['k.rb:1:0'].map(&:top)
    assert_equal ['()', 'value'], tops
  end

  test 'St3e20', %w(
  | Example: a class with initialize, on one line, and ship,
  | over three
  | Each def's last line, by its site, where its card ends.
  ) do
    source = <<~RUBY
      class Shop
        def initialize; end

        def ship(order)
          order.pack
        end
      end
    RUBY
    lasts = PathCoverage::MethodStatements.lasts(source, 'k.rb')
    assert_equal({ 'k.rb:2:2' => 2, 'k.rb:4:2' => 6 }, lasts)
  end

  private

  # { def site => its statements' rows } for source, as if it
  # were k.rb.
  def statements(source)
    PathCoverage::MethodStatements.of(source, 'k.rb')
  end
end
