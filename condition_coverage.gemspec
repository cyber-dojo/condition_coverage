require_relative 'lib/condition_coverage'

Gem::Specification.new do |s|
  s.name = 'condition_coverage'
  s.version = ConditionCoverage::VERSION
  s.summary = 'Condition coverage for Ruby, alongside SimpleCov branch coverage'
  s.description = 'Placeholder release outlining the idea; see the README.'
  s.authors = ['Jon Jagger']
  s.license = 'BSD-2-Clause'
  s.homepage = 'https://github.com/cyber-dojo/condition_coverage'
  s.files = ['lib/condition_coverage.rb', 'README.md', 'LICENSE.md']
  s.add_dependency 'prism', '~> 1.0'
end
