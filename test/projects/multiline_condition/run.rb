require 'coverage'
require 'json'

Coverage.start(lines: true)
if ENV.fetch('CONDITIONS') == 'on'
  require 'condition_coverage'
  ConditionCoverage.start(on_exit: proc {}) do
    root __dir__
    cover 'source/**/*.rb'
    coverage_dir ENV.fetch('COVERAGE_DIR')
  end
end

require_relative 'source/kata'
Kata.ok?('N1')
Kata.image?('docker.io/ruby')
kata = File.expand_path('source/kata.rb', __dir__)
puts JSON.generate(Coverage.result.fetch(kata)[:lines])
