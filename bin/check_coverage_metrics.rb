#!/usr/bin/env ruby
require 'json'
require_relative '../test/coverage_metrics_check'

HELP = <<~TEXT.freeze
  Usage: bin/check_coverage_metrics.rb [OPTIONS] [REPORT] [PARAMS]

  Checks a coverage report against the min..max bounds in a
  params file, printing each breached bound, and exits non-zero
  if any bound is breached.

  REPORT defaults to reports/coverage_metrics.json, which
  bin/run_tests.sh writes; PARAMS to
  test/coverage_metrics_params.json.

  Options:
    -h    Show this help

  Example:
    bin/check_coverage_metrics.rb
TEXT

ROOT = File.expand_path('..', __dir__)

# The parsed JSON at path, or exits naming what is wrong with it.
def read_json(path)
  JSON.parse(File.read(path))
rescue Errno::ENOENT
  abort("#{path}: no such file")
rescue JSON::ParserError => e
  abort("#{path}: not valid JSON: #{e.message}")
end

if ARGV.first == '-h'
  puts HELP
  exit 0
end

report = ARGV[0] || "#{ROOT}/reports/coverage_metrics.json"
params = ARGV[1] || "#{ROOT}/test/coverage_metrics_params.json"
bounds = read_json(params).fetch('bounds') do
  abort("#{params}: no \"bounds\" key, so nothing would be checked")
end
breaches = CoverageMetricsCheck.breaches(read_json(report), bounds)
breaches.each { |line| puts line }
puts breaches.empty? ? 'coverage: ALLOWED' : 'coverage: DENIED'
exit breaches.empty?
