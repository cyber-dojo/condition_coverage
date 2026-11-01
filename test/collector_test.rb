require_relative 'test_helper'
require 'condition_coverage/collector'
require 'condition_coverage/post'
require 'json'
require 'open3'
require 'socket'
require 'tmpdir'

class CollectorTest < Id58TestBase
  # Its tests listen on ports and spawn a collector, which
  # must not take each other's connections.
  serial!

  test 'Cl4k10', %w(
  | the collector saves each JSON report POSTed to it as a
  | file of its own, numbered in the order they arrive,
  | ready to be merged and rendered once every run is done
  ) do
    dir = Dir.mktmpdir('Cl4k10')
    server = TCPServer.new('127.0.0.1', 0)
    url = "http://127.0.0.1:#{server.addr[1]}/runs"
    collector = ConditionCoverage::Collector
    serving = Thread.new { collector.serve(server, dir) }
    [[2, 0], [0, 1]].each do |truthy, falsy|
      operands = { 'source/kata.rb:3:23' => [{ truthy:, falsy: }] }
      ConditionCoverage::Post.deliver(operands, url)
    end
    serving.kill
    server.close

    expected = {
      'run-0001.json' => report(2, 0),
      'run-0002.json' => report(0, 1)
    }
    actual = Dir.children(dir).sort.to_h do |name|
      [name, JSON.parse(File.read("#{dir}/#{name}"))]
    end
    assert_equal expected, actual
  end

  test 'Cl4k15', %w(
  | a connection that sends no request, eg a check that the
  | collector is up, saves nothing and uses up no number
  ) do
    dir = Dir.mktmpdir('Cl4k15')
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    collector = ConditionCoverage::Collector
    serving = Thread.new { collector.serve(server, dir) }
    TCPSocket.new('127.0.0.1', port).close
    operands = { 'source/kata.rb:3:23' => [{ truthy: 2, falsy: 0 }] }
    ConditionCoverage::Post.deliver(operands, "http://127.0.0.1:#{port}/")
    serving.kill
    server.close
    actual = Dir.children(dir).to_h do |name|
      [name, JSON.parse(File.read("#{dir}/#{name}"))]
    end
    assert_equal({ 'run-0001.json' => report(2, 0) }, actual)
  end

  test 'Cl4k20', %w(
  | the collector command's -h prints its usage, with an
  | example, and exits 0
  ) do
    stdout, stderr, status = Open3.capture3(*command('-h'))
    assert_equal ['', 0], [stderr, status.exitstatus]
    name = 'condition_coverage_collector'
    assert_includes stdout, "Usage: #{name} PORT DIR"
    assert_includes stdout, "#{name} 4570 "
  end

  test 'Cl4k30', %w(
  | the collector command listens on PORT and saves each
  | report POSTed to it in DIR, creating DIR if need be
  ) do
    dir = "#{Dir.mktmpdir('Cl4k30')}/runs"
    probe = TCPServer.new('127.0.0.1', 0)
    port = probe.addr[1]
    probe.close
    pid = Process.spawn(*command(port.to_s, dir))
    wait_until_listening(port)
    operands = { 'source/kata.rb:3:23' => [{ truthy: 1, falsy: 1 }] }
    ConditionCoverage::Post.deliver(operands, "http://127.0.0.1:#{port}/")
    Process.kill('TERM', pid)
    Process.wait(pid)
    counts = { 'truthy' => 1, 'falsy' => 1 }
    expected = { 'sites' => { 'source/kata.rb:3:23' => [counts] } }
    saved = File.read("#{dir}/run-0001.json")
    assert_equal expected, JSON.parse(saved)
  end

  # The collector command, with args, run from this checkout.
  def command(*args)
    root = File.expand_path('..', __dir__)
    exe = "#{root}/exe/condition_coverage_collector"
    ['ruby', "-I#{root}/lib", exe, *args]
  end

  # Returns once something accepts connections on port.
  def wait_until_listening(port)
    50.times do
      TCPSocket.new('127.0.0.1', port).close
      return
    rescue Errno::ECONNREFUSED
      sleep(0.1)
    end
  end

  # The parsed JSON report of one operand of one site.
  def report(truthy, falsy)
    counts = { 'truthy' => truthy, 'falsy' => falsy }
    { 'sites' => { 'source/kata.rb:3:23' => [counts] } }
  end
end
