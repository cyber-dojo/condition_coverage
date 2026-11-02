module ConditionCoverage
  # The terminal worklist: one line per missing outcome, and
  # nothing for a site seen both ways. Every count stays in
  # the operands for reporters that show them all.
  module Gaps
    # The gap lines of operands and outcomes, as Result gives
    # them, eg "k.rb:2:2 operand 0 never false", in manifest
    # order.
    def self.lines(operands, outcomes = {})
      operands.flat_map do |site, counts|
        site_gaps(site, counts, outcomes[site])
      end
    end

    # One line for a site that never ran, else one for a gap
    # in its outcome, then one per gap in its operands.
    def self.site_gaps(site, operands, outcome)
      if operands.all? { |counts| never_ran?(counts) }
        return ["#{site} never reached"]
      end

      own = outcome_gap(outcome, operands.size)
      own.map { |gap| "#{site} outcome #{gap}" } +
        operand_gaps(site, operands)
    end

    # One line per gap in a site's operands.
    def self.operand_gaps(site, operands)
      operands.each_with_index.flat_map do |counts, index|
        operand_gap(counts).map do |gap|
          "#{site} operand #{index} #{gap}"
        end
      end
    end

    # The one outcome a ternary of several leaves is missing,
    # if any: an arm that never ran. A ternary of one leaf has
    # that leaf's gap instead, and any other site's outcome is
    # shown but is never a gap, its leaves' gaps telling more.
    def self.outcome_gap(outcome, leaves)
      return [] unless outcome&.dig(:ternary) && leaves > 1
      return ['never true'] if outcome[:truthy].zero?
      return ['never false'] if outcome[:falsy].zero?

      []
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
