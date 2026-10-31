# Runs the demo source tree under condition coverage, as a
# test suite would, writing the report to COVERAGE_DIR.
require 'condition_coverage'

ConditionCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
  report :gaps, :html
end

require_relative 'source/kata'
require_relative 'source/group'
require_relative 'source/team'

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
