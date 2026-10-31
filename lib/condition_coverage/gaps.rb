module ConditionCoverage
  # The terminal worklist: one line per missing outcome, and
  # nothing for a site seen both ways. Every count stays in
  # the Result for reporters that show them all.
  module Gaps
    # The gap lines of result, eg "k.rb:2:2 operand 0 never
    # false", in manifest order.
    def self.lines(result)
      result.operands.flat_map do |site, operands|
        site_gaps(site, operands)
      end
    end

    # One line for a site that never ran, else one per gap
    # in its operands.
    def self.site_gaps(site, operands)
      if operands.all? { |counts| never_ran?(counts) }
        return ["#{site} never reached"]
      end

      operands.each_with_index.flat_map do |counts, index|
        operand_gap(counts).map do |gap|
          "#{site} operand #{index} #{gap}"
        end
      end
    end

    # The one outcome this operand is missing, if any.
    def self.operand_gap(counts)
      return ['never evaluated'] if never_ran?(counts)
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
