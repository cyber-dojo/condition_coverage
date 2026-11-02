module PathCoverage
  # What the reports say about each site's paths beyond their
  # counts, worked out from each covered file's source: where
  # each leaf is, and what it says.
  module PathsReport
    # { site => { leaves:, taken: } }: taken is each path and
    # its count, as Result#paths gives them, and leaves each
    # leaf's ["line:column", "line:column"] span, so a tool can
    # recover each leaf exactly. files is { full path =>
    # {source:, sites:} }.
    def self.of(site_paths, files)
      spans = leaf_spans(files)
      site_paths.to_h do |site, taken|
        [site, { leaves: spans.fetch(site), taken: }]
      end
    end

    # { site => [each leaf's source text] } for every site in
    # files.
    def self.texts(files)
      each_site(files) do |source, condition|
        condition.leaves.map { |range| source.byteslice(range) }
      end
    end

    # { site => [each leaf's span] } for every site in files.
    def self.leaf_spans(files)
      each_site(files) do |source, condition|
        condition.leaves.map do |range|
          [at(source, range.begin), at(source, range.end)]
        end
      end
    end

    # { site => what the block makes of its file's source and
    # its condition } for every site in files.
    def self.each_site(files)
      files.values.each_with_object({}) do |parsed, all|
        parsed[:sites].each do |site, condition|
          all[site] = yield(parsed[:source], condition)
        end
      end
    end

    # "line:column" of a byte offset in source, the line from
    # 1 and the column, in characters, from 0, as site names
    # count them.
    def self.at(source, offset)
      before = source.byteslice(0, offset)
      line = before.count("\n") + 1
      start = before.rindex("\n")
      "#{line}:#{before.length - (start ? start + 1 : 0)}"
    end
  end
end
