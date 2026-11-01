require 'net/http'
require_relative 'json_writer'

module ConditionCoverage
  # The :post reporter: sends the JSON report to a collector,
  # for runs whose own files are thrown away, eg a failing
  # docker build step.
  module Post
    # POSTs operands, as the JSON report, to url, never through
    # an http_proxy, which could not reach a collector local to
    # the run. A collector that cannot be reached, or does not
    # answer within a second, is passed over in silence: the
    # run's own output and exit status must stay as they are.
    def self.deliver(operands, url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.open_timeout = http.read_timeout = 1
      headers = { 'Content-Type' => 'application/json' }
      http.post(uri.path, JsonWriter.json(operands), headers)
    rescue StandardError
      nil
    end
  end
end
