# Runs the demo source tree under path coverage, as a
# test suite would, writing the report to COVERAGE_DIR.
require 'path_coverage'

PathCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
  report :gaps, :html
  measure :conditions, :paths
end

require_relative 'source/kata'
require_relative 'source/group'
require_relative 'source/team'
require_relative 'source/shop'

KataState = Data.define(:started, :finished)
GroupState = Data.define(:size, :open)
Member = Data.define(:owner, :editor, :invite_open, :active)

# Every outcome of both operands: covered.
Kata.id?('Kp9sA2')
Kata.id?(42)
Kata.id?('Kp9')

# Over two lines; the kata is never finished: never false.
Kata.runnable?(KataState.new(started: true, finished: false))
Kata.runnable?(KataState.new(started: false, finished: false))

# Two conditions on one line, the second with gaps.
Kata.pair_checks('Kp9sA2', 'Kp9sA2')

# Every outcome of both operands: covered.
Group.full?(GroupState.new(size: 64, open: true))
Group.full?(GroupState.new(size: 64, open: false))
Group.full?(GroupState.new(size: 1, open: true))

# A chain of three over two lines; no name is ever too long.
Team.name?('alice', [])
Team.name?('alice', ['alice'])
Team.name?('Al', [])

# A grouped && inside an ||; no open invite is ever seen.
owner = Member.new(owner: true, editor: false, invite_open: false,
                   active: true)
editor = Member.new(owner: false, editor: true, invite_open: false,
                    active: true)
Team.can_edit?(owner)
Team.can_edit?(editor)

# A site inside a block, inside an || site of its own.
Team.led?([owner])
Team.led?([])

# The shop: some choices made every way, some never.
alice = { member: true, banned: false, spend: 2000, invited: false }
bob = { member: false, banned: false, spend: 0, coupon: true }
Shop.member?(alice)
Shop.member?(bob)
# A banned member: member? is now covered.
Shop.member?({ member: true, banned: true })
gift = { items: [{ price: 80 }], gift: true, wrap: false }
pickup = { items: [{ price: 20 }], pickup: true, express: true }
Shop.price(alice, gift)
Shop.price(bob, pickup)
begin
  Shop.price(bob, { items: [] })
rescue ArgumentError
  # An empty order fails, as it should.
end
Shop.install_discounts([])
Shop.install_discounts([0.1, 0.2])
Shop.discount(100, 0.1)
# A zero rate, and a zero total: discount's && is covered.
Shop.discount(100, 0)
Shop.discount(0, 0.1)
Shop.labels([{ sale: true, price: 5 }, { sale: false, price: 20 }])
Shop.greeting({ name: 'Ann' })
# No name, and an empty one: greeting is covered.
Shop.greeting({})
Shop.greeting({ name: '' })
