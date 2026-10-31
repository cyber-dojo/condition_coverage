require_relative 'lib/condition_coverage/version'

Gem::Specification.new do |s|
  s.name = 'condition_coverage'
  s.version = ConditionCoverage::VERSION
  s.summary = 'Condition coverage for Ruby, ' \
              'alongside SimpleCov branch coverage'
  s.description = 'Placeholder release outlining the idea; ' \
                  'see the README.'
  s.authors = ['Jon Jagger']
  s.license = 'BSD-2-Clause'
  s.homepage = 'https://github.com/cyber-dojo/condition_coverage'
  s.files = Dir['lib/**/*.rb'] + %w[README.md LICENSE.md]
  # String#bytesplice arrived in Ruby 3.2.
  s.required_ruby_version = '>= 3.2'
  s.add_dependency 'prism', '~> 1.0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
