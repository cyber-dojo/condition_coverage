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

KataState = Data.define(:started, :finished)
GroupState = Data.define(:size, :open)

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
