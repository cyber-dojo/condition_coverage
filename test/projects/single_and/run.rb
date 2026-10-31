require 'condition_coverage'

ConditionCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
end

require_relative 'source/kata'
Kata.kata?('N1')
Kata.kata?('')
