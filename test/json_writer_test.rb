require_relative 'test_helper'
require 'condition_coverage/json_writer'
require 'condition_coverage/result'
require 'json'
require 'tmpdir'

class JsonWriterTest < Id58TestBase
  test 'wdt910', %w(
  | the result is written as raw JSON under "sites",
  | the base every other reporter reads
  ) do
    sites = { 'k.rb:2:2' => condition('&&', 16...23, 27...35) }
    counts = { ['k.rb:2:2', 0] => { truthy: 1, falsy: 1 } }
    result = ConditionCoverage::Result.new(sites, counts)
    path = "#{Dir.mktmpdir('wdt910')}/condition_coverage.json"
    ConditionCoverage::JsonWriter.write(result, path)
    expected = {
      'sites' => {
        'k.rb:2:2' => [
          { 'truthy' => 1, 'falsy' => 1 },
          { 'truthy' => 0, 'falsy' => 0 }
        ]
      }
    }
    actual = JSON.parse(File.read(path))
    assert_equal expected, actual
  end
end
