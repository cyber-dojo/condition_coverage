module ConditionCoverage
  # Instruments source text so that each && operand records its
  # outcome when the code runs. It inserts text at the byte
  # ranges the manifest found, and never parses.
  module Rewriter
    # Returns source with each operand in sites wrapped in a
    # record call. Only text is inserted, never a newline, so
    # backtrace line numbers still match the file on disk.
    def self.rewrite(source, sites)
      inserts = sites.flat_map do |site, ranges|
        ranges.each_with_index.flat_map do |range, index|
          wrap(site, index, range)
        end
      end
      apply(source.dup, inserts)
    end

    # The two inserts that wrap one operand in a record call.
    def self.wrap(site, index, range)
      call = "ConditionCoverage.record(#{site.inspect}, #{index}, "
      [[range.begin, call], [range.end, ')']]
    end

    # Splices each [offset, text] insert into source,
    # last offset first so earlier offsets stay valid.
    def self.apply(source, inserts)
      sorted = inserts.sort_by { |offset, _| -offset }
      sorted.each do |offset, text|
        source.bytesplice(offset, 0, text)
      end
      source
    end
  end
end
