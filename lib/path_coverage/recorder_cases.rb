module PathCoverage
  # The part of the recorder that notes a case nested in another
  # site, eg (case a when 1 then b end) && c: the site around it
  # enters and leaves, so its patterns only note whether they
  # matched. It relies on its includer's record.
  module RecorderCases
    # A stand-in for the pattern of a case nested in site, its
    # match noted as the site's index-th leaf.
    NestedMatch = Struct.new(:recorder, :site, :index, :pattern) do
      # Whether pattern matches subject, exactly as pattern says,
      # noted on the site's path.
      def ===(subject)
        recorder.record(site, index, pattern === subject)
      end
    end

    # The stand-in for pattern, the index-th leaf of site, in a
    # case nested in it.
    def pattern(site, index, pattern)
      NestedMatch.new(self, site, index, pattern)
    end
  end
end
