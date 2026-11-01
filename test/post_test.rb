require_relative 'test_helper'
require 'condition_coverage/configuration'
require 'condition_coverage/render'
require 'json'
require 'socket'
require 'tmpdir'

class PostTest < Id58TestBase
  # Its tests capture $stdout, which is process-wide.
  serial!

  test 'Pq3s10', %w(
  | with report :post the operands are POSTed as the JSON
  | report to the collector url, printing nothing, so a run
  | whose stdout and stderr are checked exactly is unchanged
  ) do
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    received = Thread.new { request_body(server.accept) }
    operands = {
      'source/kata.rb:3:23' => [
        { truthy: 2, falsy: 1 },
        { truthy: 1, falsy: 0, only: :truthy }
      ]
    }
    config = post_config('Pq3s10', "http://127.0.0.1:#{port}/runs")
    assert_output('', '') do
      ConditionCoverage::Render.run(operands, {}, config)
    end
    expected = {
      'sites' => {
        'source/kata.rb:3:23' => [
          { 'truthy' => 2, 'falsy' => 1 },
          { 'truthy' => 1, 'falsy' => 0, 'only' => 'truthy' }
        ]
      }
    }
    assert_equal expected, JSON.parse(received.join(5).value)
  end

  test 'Pq3s20', %w(
  | a collector that cannot be reached is passed over in
  | silence, so a run without one still exits as it would
  ) do
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    config = post_config('Pq3s20', "http://127.0.0.1:#{port}/runs")
    operands = { 'source/kata.rb:3:23' => [{ truthy: 1, falsy: 0 }] }
    assert_output('', '') do
      ConditionCoverage::Render.run(operands, {}, config)
    end
  end

  test 'Pq3s30', %w(
  | a collector that accepts the connection but never
  | answers is given up on within two seconds, so it
  | cannot hang the run that is exiting
  ) do
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    config = post_config('Pq3s30', "http://127.0.0.1:#{port}/runs")
    operands = { 'source/kata.rb:3:23' => [{ truthy: 1, falsy: 0 }] }
    started = now
    assert_output('', '') do
      ConditionCoverage::Render.run(operands, {}, config)
    end
    elapsed = now - started
    server.close
    assert elapsed < 2, "took #{elapsed.round(1)}s"
  end

  test 'Pq3s40', %w(
  | an http_proxy in the environment, as a docker build
  | often has, is not used, since the collector is local
  | to the build and a proxy would not reach it
  ) do
    dead = TCPServer.new('127.0.0.1', 0)
    dead_port = dead.addr[1]
    dead.close
    # Not loopback, which Net::HTTP never proxies anyway.
    host = Socket.ip_address_list.find(&:ipv4_private?).ip_address
    server = TCPServer.new(host, 0)
    port = server.addr[1]
    received = Thread.new { request_body(server.accept) }
    config = post_config('Pq3s40', "http://#{host}:#{port}/runs")
    operands = { 'source/kata.rb:3:23' => [{ truthy: 1, falsy: 0 }] }
    with_env('http_proxy', "http://127.0.0.1:#{dead_port}") do
      ConditionCoverage::Render.run(operands, {}, config)
    end
    sites = JSON.parse(received.join(3).value)['sites']
    assert_equal ['source/kata.rb:3:23'], sites.keys
  end

  # Seconds on the monotonic clock, for timing a call.
  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Runs the block with ENV[name] set to value, then
  # restores it.
  def with_env(name, value)
    saved = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = saved
  end

  # A configuration choosing only :post, to url.
  def post_config(id, url)
    dir = Dir.mktmpdir(id)
    ConditionCoverage::Configuration.new do
      root dir
      cover '*.rb'
      coverage_dir dir
      collector url
      report :post
    end
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
