module PathCoverage
  # The terminal worklist: one line per path a site never
  # took, and nothing for a site that took them all. Every
  # count stays in the operands and paths for reporters that
  # show them all.
  module Gaps
    # The gap lines of operands and paths, as Result gives
    # them, in manifest order; texts is { site => each leaf's
    # source text }.
    def self.lines(operands, paths: {}, texts: {})
      operands.flat_map do |site, counts|
        if counts.all? { |each| never_ran?(each) }
          next ["#{site} never reached"]
        end

        path_gaps(site, paths.fetch(site, []), texts[site])
      end
    end

    # One line per path site never took, as Result#paths gives
    # them, naming the outcome of each leaf the path reaches,
    # texts being each leaf's source text.
    def self.path_gaps(site, paths, texts)
      paths.select { |each| each[:count].zero? }.map do |each|
        steps = each[:path].zip(texts).filter_map do |outcome, text|
          "#{code(text)} #{outcome}" unless outcome.nil?
        end
        "#{site} path never taken: #{steps.join(', ')}"
      end
    end

    # text as a markdown code span on one line: each run of
    # whitespace one space, fenced by a run of backticks one
    # longer than any inside it, with a space inside the fence
    # when text starts or ends with one.
    def self.code(text)
      text = text.gsub(/\s+/, ' ')
      longest = text.scan(/`+/).map(&:size).max || 0
      fence = '`' * (longest + 1)
      pad = text.start_with?('`') || text.end_with?('`') ? ' ' : ''
      "#{fence}#{pad}#{text}#{pad}#{fence}"
    end

    # The one outcome this operand is missing, if any; a fixed
    # leaf, which can have one outcome only, needs only to run.
    def self.operand_gap(counts)
      return ['never evaluated'] if never_ran?(counts)
      return [] if counts[:only]
      return ['never true'] if counts[:truthy].zero?
      return ['never false'] if counts[:falsy].zero?

      []
    end

    # True when the operand was never recorded either way.
    def self.never_ran?(counts)
      counts[:truthy].zero? && counts[:falsy].zero?
    end
  end
end
