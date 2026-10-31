require 'condition_coverage'

ConditionCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
end

require_relative 'source/kata'
Kata.either?('N1')
Kata.either?('ABCDEF')
Kata.kata?('N12')
Kata.kata?('')
Kata.group?('G1')
Kata.group?('')
Kata.listed?(['ab'])
Kata.listed?([])
Kata.both?('N1')
Kata.both?('')
