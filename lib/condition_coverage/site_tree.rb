require_relative 'gaps'

module ConditionCoverage
  # The tree shown under a site's line on its file's page.
  module SiteTree
    # { operator:, operands: [{text:, truthy:, falsy:, gap:}] }
    # for one && site: each operand's text cut from source at
    # its manifest byte range, its counts, and its gap label in
    # the same words as the terminal gaps list (nil for none).
    def self.of(source, ranges, counts)
      operands = ranges.zip(counts).map do |range, operand|
        {
          text: source.byteslice(range),
          truthy: operand[:truthy], falsy: operand[:falsy],
          gap: Gaps.operand_gap(operand).first
        }
      end
      { operator: '&&', operands: }
    end
  end
end
