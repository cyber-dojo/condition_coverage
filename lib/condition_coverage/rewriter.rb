module ConditionCoverage
  # Instruments source text so that each leaf operand records its
  # outcome when the code runs. It inserts text at the byte
  # ranges the manifest found, and never parses.
  module Rewriter
    PATH_NAME = '__condition_coverage_path'.freeze

    # Returns source with each operand in sites wrapped in a
    # record call, what decides each site's own outcome in an
    # outcome call, and each method in methods starting a path
    # that its decisions are wrapped in decide calls to add to.
    # Only text is inserted, never a newline, so backtrace line
    # numbers still match the file on disk.
    def self.rewrite(source, sites, methods = {})
      inserts = sites.flat_map do |site, condition|
        record_inserts(site, condition) +
          outcome_inserts(site, condition)
      end
      apply(source.dup, inserts + path_inserts(methods))
    end

    # The inserts that wrap each of site's leaves in a record
    # call, innermost of all.
    def self.record_inserts(site, condition)
      condition.leaves.each_with_index.flat_map do |range, index|
        command = condition.commands.include?(range)
        wrap(record_call(site, index), range, command, 0)
      end
    end

    # The inserts that wrap what decides site's own outcome in
    # an outcome call, outside its leaves' record calls.
    def self.outcome_inserts(site, condition)
      range, parens = decided(condition)
      call = "ConditionCoverage.outcome(#{site.inspect}, "
      wrap(call, range, parens, 1)
    end

    WORD_OPERATORS = %w[and or].freeze

    # The byte range deciding condition's own outcome, and
    # whether it needs parentheses to be an argument: a
    # ternary's predicate, parenthesised when a command call;
    # any other site as a whole, parenthesised when an and or
    # or, which, like a command call, is no bare argument.
    def self.decided(condition)
      unless condition.operator == '?:'
        word = WORD_OPERATORS.include?(condition.operator)
        return [condition.extent, word]
      end

      predicate = condition.operands.first
      return [predicate.extent, false] if predicate.is_a?(Condition)

      [predicate, condition.commands.include?(predicate)]
    end

    # The opening of the record call around operand index of
    # the site.
    def self.record_call(site, index)
      "ConditionCoverage.record(#{site.inspect}, #{index}, "
    end

    # The inserts that start each method's path at its entry,
    # outermost of all there, and wrap each of its decisions'
    # predicates in a decide call, outside any record or
    # outcome call.
    def self.path_inserts(methods)
      methods.flat_map do |site, method|
        decisions = method.decisions
        start = path_start(site, decisions.size)
        decides = decisions.each_with_index.flat_map do |decision, i|
          call = "ConditionCoverage.decide(#{PATH_NAME}, #{i}, "
          tail = decision.exits.nil? ? '' : ", #{decision.exits}"
          wrap(call, decision.range, decision.command, 2, tail)
        end
        [[method.entry, start, 3]] + decides
      end
    end

    # The statement that starts a call's path through the
    # method at site, which has size decisions.
    def self.path_start(site, size)
      call = "ConditionCoverage.path(#{site.inspect}, #{size})"
      "#{PATH_NAME} = #{call}; "
    end

    # The two inserts that wrap the code at range in call, of
    # rank among inserts at the same offset, with tail as the
    # call's further arguments. A command call is parenthesised,
    # as it is no bare argument; nothing else is, since
    # parentheses make a statement, which gives its line a
    # line-coverage count of its own.
    def self.wrap(call, range, command, rank, tail = '')
      open, close = command ? ['(', ")#{tail})"] : ['', "#{tail})"]
      [[range.begin, call + open, rank], [range.end, close, rank]]
    end

    # Splices each [offset, text, rank] insert into source, last
    # offset first so earlier offsets stay valid. At one offset
    # the higher rank goes in last, so it ends up outermost.
    def self.apply(source, inserts)
      sorted = inserts.sort_by { |offset, _, rank| [-offset, rank] }
      sorted.each do |offset, text, _|
        source.bytesplice(offset, 0, text)
      end
      source
    end
  end
end
