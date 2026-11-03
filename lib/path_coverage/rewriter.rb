require_relative 'condition'

module PathCoverage
  # Instruments source text so that each leaf operand records its
  # outcome when the code runs. It inserts text at the byte
  # ranges the manifest found, and never parses.
  module Rewriter
    PATH_NAME = '__path_coverage_path'.freeze

    # Returns source with each operand in sites wrapped in a
    # record call, each site as a whole in a leave call that
    # enters it first, and each method in methods starting a
    # path that its decisions are wrapped in decide calls to add
    # to. Only text is inserted, never a newline, so backtrace
    # line numbers still match the file on disk.
    def self.rewrite(source, sites, methods = {})
      inserts = sites.flat_map do |site, condition|
        site_inserts(site, condition)
      end
      apply(source.dup, inserts + path_inserts(methods))
    end

    # The inserts for one site, by its kind: a case's patterns'
    # stand-ins, a block method's call and block, or any other
    # site's leaves' records and its leave.
    def self.site_inserts(site, condition)
      kind = condition.operator
      return case_inserts(site, condition) if kind == 'case'

      blocks = BLOCK_PATHS.key?(kind)
      return block_inserts(site, condition) if blocks

      record_inserts(site, condition) + trail_inserts(site, condition)
    end

    # The inserts that wrap a block method's call whole in a
    # leave_items call that enters it first, inside any leave of
    # a site it is the predicate of, and its block's expression,
    # outside any site's leave there, in an item call, noting its
    # last answer, or for a method that calls it with every item
    # an answer call, noting every answer.
    def self.block_inserts(site, condition)
      _receiver, body = condition.leaves
      enter = "PathCoverage.enter_items(#{site.inspect})"
      call = "PathCoverage.leave_items(#{enter}, "
      every = EVERY_ITEM.include?(condition.operator)
      noter = every ? 'answer' : 'item'
      item = "PathCoverage.#{noter}(#{site.inspect}, "
      command = condition.commands.include?(body)
      wrap(call, condition.extent, false, 0.5) +
        wrap(item, body, command, 1.5)
    end

    # The inserts that wrap each pattern of a case site in a
    # when_match call, its stand-in, which enters and leaves the
    # site itself, as the case tries its patterns one by one.
    def self.case_inserts(site, condition)
      size = condition.leaves.size
      condition.leaves.each_with_index.flat_map do |range, index|
        call = "PathCoverage.when_match(#{site.inspect}, " \
               "#{index}, #{size}, "
        wrap(call, range, false, 0)
      end
    end

    # The inserts that wrap each of site's leaves in a record
    # call, innermost of all.
    def self.record_inserts(site, condition)
      condition.leaves.each_with_index.flat_map do |range, index|
        command = condition.commands.include?(range)
        wrap(record_call(site, index), range, command, 0)
      end
    end

    WORD_OPERATORS = %w[and or].freeze

    # The inserts that wrap site as a whole in a leave call,
    # outside its leaves' record calls, whose first argument
    # enters the site before any leaf runs, so each evaluation
    # fills in a trail of its own. An and or or is held in
    # parentheses, being, like a command call, no bare argument.
    def self.trail_inserts(site, condition)
      enter = "PathCoverage.enter(#{site.inspect}, " \
              "#{condition.leaves.size})"
      call = "PathCoverage.leave(#{enter}, "
      wrapped = trailed(condition)
      nested = wrapped.is_a?(Condition)
      word = nested && WORD_OPERATORS.include?(wrapped.operator)
      wrap(call, nested ? wrapped.extent : wrapped, word, 1)
    end

    # What a site's leave call wraps: an if's or an unless's
    # predicate, a leaf's byte range or a nested Condition, as
    # its path is decided there and its arms are statements that
    # may return or raise; any other site as a whole.
    def self.trailed(condition)
      unless STATEMENT_CHOICES.include?(condition.operator)
        return condition
      end

      condition.operands.first
    end

    # The opening of the record call around operand index of
    # the site.
    def self.record_call(site, index)
      "PathCoverage.record(#{site.inspect}, #{index}, "
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
          call = "PathCoverage.decide(#{PATH_NAME}, #{i}, "
          tail = decision.exits.nil? ? '' : ", #{decision.exits}"
          wrap(call, decision.range, decision.command, 2, tail)
        end
        [[method.entry, start, 3]] + decides
      end
    end

    # The statement that starts a call's path through the
    # method at site, which has size decisions.
    def self.path_start(site, size)
      call = "PathCoverage.path(#{site.inspect}, #{size})"
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
      [
        [range.begin, call + open, rank],
        [range.end, close, rank, :close]
      ]
    end

    # Splices each [offset, text, rank] insert into source, last
    # offset first so earlier offsets stay valid; a closing
    # insert is marked :close. Text spliced in later at an
    # offset lands before text already there, so at one offset
    # opening inserts go in lowest rank first, leaving the
    # highest outermost, then closing ones highest rank first,
    # so the innermost call closes first and each tail stays
    # with its own call.
    def self.apply(source, inserts)
      sorted = inserts.sort_by do |offset, _, rank, close|
        close ? [-offset, 1, -rank] : [-offset, 0, rank]
      end
      sorted.each do |offset, text, _|
        source.bytesplice(offset, 0, text)
      end
      source
    end
  end
end
