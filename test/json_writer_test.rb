require_relative 'test_helper'
require 'path_coverage/json_writer'
require 'path_coverage/result'
require 'json'
require 'tmpdir'

class JsonWriterTest < Id58TestBase
  test 'wdt910', %w(
  | the result is written as raw JSON under "sites",
  | the base every other reporter reads, with the names of
  | the kinds of site measured under "kinds", so runs that
  | measured different kinds are never merged
  ) do
    sites = { 'k.rb:2:2' => condition('&&', 16...23, 27...35) }
    counts = { ['k.rb:2:2', 0] => { truthy: 1, falsy: 1 } }
    operands = PathCoverage::Result.new(sites, counts).operands
    path = "#{Dir.mktmpdir('wdt910')}/path_coverage.json"
    PathCoverage::JsonWriter.write(operands, path)
    expected = {
      'sites' => {
        'k.rb:2:2' => [
          { 'truthy' => 1, 'falsy' => 1 },
          { 'truthy' => 0, 'falsy' => 0 }
        ]
      },
      'kinds' => %w(block case chain choice contains safe write)
    }
    actual = JSON.parse(File.read(path))
    assert_equal expected, actual
  end

  test 'wdt911', %w(
  | Example: a run with ignore '&&='
  | The operators ignored are written under "ignored", so its
  | report is never merged with one that measured &&= writes.
  ) do
    sites = { 'k.rb:2:2' => condition('&&', 16...23, 27...35) }
    counts = { ['k.rb:2:2', 0] => { truthy: 1, falsy: 1 } }
    operands = PathCoverage::Result.new(sites, counts).operands
    path = "#{Dir.mktmpdir('wdt911')}/path_coverage.json"
    fingerprint = { 'ignored' => ['&&='] }
    PathCoverage::JsonWriter.write(operands, path, fingerprint:)
    actual = JSON.parse(File.read(path))
    assert_equal ['&&='], actual['ignored']
  end
end
