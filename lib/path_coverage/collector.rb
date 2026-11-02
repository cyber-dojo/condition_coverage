module PathCoverage
  # Receives the JSON reports the :post reporter sends, so the
  # runs that sent them, eg failing docker build steps, can
  # be merged and rendered once they are all done.
  module Collector
    # Answers every request on server, forever, saving each
    # body in dir as run-0001.json, run-0002.json, and so on,
    # in the order they arrive. A connection sending no
    # request, eg a check that the collector is up, is skipped.
    def self.serve(server, dir)
      n = 0
      loop do
        body = request_body(server.accept)
        next if body.nil?

        n += 1
        File.write(format('%<dir>s/run-%<n>04d.json', dir:, n:), body)
      end
    end

    # The body of the one HTTP request on client, after
    # answering it 200; nil, unanswered, when client closes
    # without sending a request.
    def self.request_body(client)
      headers = []
      while (line = client.gets) && line != "\r\n"
        headers << line
      end
      body = headers.empty? ? nil : answer(client, headers)
      client.close
      body
    end

    # The body of a request with headers, read from client,
    # which is then answered 200.
    def self.answer(client, headers)
      length = headers.sum do |line|
        name, value = line.split(':', 2)
        name.casecmp?('content-length') ? value.to_i : 0
      end
      body = client.read(length)
      client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      body
    end
  end
end
