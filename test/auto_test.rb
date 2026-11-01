require_relative 'test_helper'
require 'condition_coverage/kernel'
require 'condition_coverage/manifest'
require 'json'
require 'open3'
require 'socket'
require 'tmpdir'

class AutoTest < Id58TestBase
  # One of its tests requires auto in this process, which
  # reads the configuration of the one global load hook.
  serial!

  test 'Au7x20', %w(
  | with no collector in the environment, requiring auto
  | starts nothing and prints nothing, so an image can set
  | RUBYOPT for every run while only some are measured
  ) do
    assert_nil ENV.fetch('CONDITION_COVERAGE_COLLECTOR', nil)
    before = ConditionCoverage.config
    assert_output('', '') { require 'condition_coverage/auto' }
    # equal? as before is nil when no test has started yet.
    assert before.equal?(ConditionCoverage.config), 'config changed'
  end

  test 'Au7x10', %w(
  | requiring condition_coverage/auto, as RUBYOPT=-r does,
  | with the settings in the environment, covers a script
  | that exits 42 and POSTs its counts to the collector,
  | leaving its stdout, stderr and exit status unchanged
  ) do
    dir = Dir.mktmpdir('Au7x10')
    source = <<~RUBY
      module KataAu7x10
        def self.kata?(id) = !id.empty? && id.start_with?('K')
      end
    RUBY
    FileUtils.mkdir_p("#{dir}/source")
    File.write("#{dir}/source/kata.rb", source)
    File.write("#{dir}/run.rb", <<~RUBY)
      require_relative 'source/kata'
      KataAu7x10.kata?('Kp9sA2')
      exit 42
    RUBY
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    received = Thread.new { request_body(server.accept) }
    env = {
      'CONDITION_COVERAGE_ROOT' => dir,
      'CONDITION_COVERAGE_COVER' => 'source/**/*.rb',
      'CONDITION_COVERAGE_DIR' => "#{dir}/condition",
      'CONDITION_COVERAGE_COLLECTOR' => "http://127.0.0.1:#{port}/runs"
    }
    lib = File.expand_path('../lib', __dir__)
    auto = '-rcondition_coverage/auto'
    command = ['ruby', "-I#{lib}", auto, "#{dir}/run.rb"]
    stdout, stderr, status = Open3.capture3(env, *command)
    assert_equal ['', '', 42], [stdout, stderr, status.exitstatus]

    path = 'source/kata.rb'
    sites = ConditionCoverage::Manifest.sites(source, path)
    expected = {
      sites.keys.first => [
        { 'truthy' => 1, 'falsy' => 0 },
        { 'truthy' => 1, 'falsy' => 0 }
      ]
    }
    assert_equal expected, JSON.parse(received.join(5).value)['sites']
  end

  # The body of the one HTTP request on client, after
  # answering it 200.
  def request_body(client)
    length = 0
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(':', 2)
      length = value.to_i if name.casecmp?('content-length')
    end
    body = client.read(length)
    client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
    client.close
    body
  end
end
