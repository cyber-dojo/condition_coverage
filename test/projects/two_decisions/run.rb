require 'path_coverage'

PathCoverage.start do
  root __dir__
  cover 'source/**/*.rb'
  coverage_dir ENV.fetch('COVERAGE_DIR')
  measure :decisions, :methods
end

require_relative 'source/shop'
Shop.fee({ member: true }, { total: 50, paid: true })
Shop.fee({ member: false }, { total: 200, paid: true })
