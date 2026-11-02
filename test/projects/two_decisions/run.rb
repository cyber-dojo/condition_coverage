require 'condition_coverage'

ConditionCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
  measure :conditions, :paths
end

require_relative 'source/shop'
Shop.fee({ member: true }, { total: 50, paid: true })
Shop.fee({ member: false }, { total: 200, paid: true })
