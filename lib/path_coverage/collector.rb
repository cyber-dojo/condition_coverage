module PathCoverage
  # Receives the JSON reports the :post reporter sends, so the
  # runs that sent them, eg failing docker build steps, can
  # be merged and rendered once they are all done.
  module Collector
    # Answers every request on server until server is closed,
    # then returns.
    # Each report is saved in dir as run-0001.json,
    # run-0002.json, and so on, in the order they arrive.
    # A connection sending no request is skipped.
    def self.serve(server, dir)
      n = 0
      while (client = accept(server))
        saved = receive(client, dir) do |body|
          save(dir, format('run-%<n>04d.json', n: n + 1), body)
        end
        n += 1 if saved
      end
    end

    # The next connection to server; nil once server is closed,
    # which is how serve is told to return.
    def self.accept(server)
      server.accept
    rescue IOError
      nil
    end

    # Saves body as dir/name whole or not at all: it is written
    # to name.tmp and renamed, so a collector stopped mid-write
    # leaves no partial report under a run's name.
    def self.save(dir, name, body)
      path = "#{dir}/#{name}"
      File.write("#{path}.tmp", body)
      File.rename("#{path}.tmp", path)
    end

    # Hands the body of the one HTTP request on client to the
    # block, which saves it, and returns whether it was saved.
    # dir is where reports are saved, which GET /ready checks.
    # A client that closes without sending a request, eg a
    # check that the collector is up, is closed unanswered and
    # nothing is saved.
    def self.receive(client, dir, &)
      headers = []
      while (line = client.gets) && line != "\r\n"
        headers << line
      end
      saved = !headers.empty? && respond(client, headers, dir, &)
      client.close
      saved
    end

    # The check each GET path makes of the collector's dir.
    # GET /alive passes whenever the collector answers.
    # GET /ready passes only when dir is a writable directory,
    # so a report sent now could be saved.
    PROBES = {
      '/alive' => ->(_dir) { true },
      '/ready' => lambda do |dir|
        File.directory?(dir) && File.writable?(dir)
      end
    }.freeze

    # Answers the request with headers on client, and returns
    # whether a report was saved in dir.
    # A GET of a path in PROBES is answered 200 when its check
    # passes, 503 when not. Nothing is saved for it.
    # Any other request is a report, handed to answer.
    def self.respond(client, headers, dir, &)
      probe = PROBES[headers.first[/\AGET (\S+) /, 1]]
      return answer(client, headers, &) if probe.nil?

      up = probe.call(dir)
      reply(client, up ? '200 OK' : '503 Service Unavailable')
      false
    end

    # Reads the body of a request with headers from client and
    # yields it to be saved. Returns whether it was saved.
    # The 200 is sent only once it is saved.
    # So a 200 always means the report is on disk.
    # A body shorter than its Content-Length is answered 400.
    # Eg its sender died mid-send. It is not saved.
    # A save that fails is answered 500.
    def self.answer(client, headers)
      length = content_length(headers)
      body = client.read(length).to_s
      whole = body.bytesize == length
      yield body if whole
      reply(client, whole ? '200 OK' : '400 Bad Request')
      whole
    rescue SystemCallError
      reply(client, '500 Internal Server Error')
      false
    end

    # The byte length headers give the request's body; 0 when
    # they give none.
    def self.content_length(headers)
      headers.sum do |line|
        name, value = line.split(':', 2)
        name.casecmp?('content-length') ? value.to_i : 0
      end
    end

    # Writes an HTTP response of status, with no body, to client.
    def self.reply(client, status)
      client.write("HTTP/1.1 #{status}\r\nContent-Length: 0\r\n\r\n")
    end
  end
end
