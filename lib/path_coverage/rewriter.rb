require_relative 'condition'
require_relative 'kinds'
require_relative 'rewriter_nested'

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

    # The inserts for one site, as its kind gives them, eg its
    # leaves' records and its leave; a block method's call or a
    # write is noted as if nested at leaf 0.
    def self.site_inserts(site, condition)
      Kinds.of(condition.operator).site_inserts(site, condition)
    end

    # The inserts that wrap each of site's leaves in a record
    # call, innermost of all; a leaf of a nested site that needs
    # a call of its own, eg a &. chain's, in the call
    # RewriterNested gives it, or in none, and that site's own
    # inserts too.
    def self.record_inserts(site, condition)
      nested = RewriterNested.calls(site, condition)
      leaves = condition.leaves
      records = leaves.each_with_index.flat_map do |range, i|
        call = nested.fetch(range) { record_call(site, i) }
        next [] unless call

        wrap(call, range, condition.commands.include?(range), :leaf)
      end
      records + RewriterNested.inserts(site, condition)
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
      wrapped = Kinds.of(condition.operator).trailed(condition)
      nested = wrapped.is_a?(Condition)
      word = nested && WORD_OPERATORS.include?(wrapped.operator)
      wrap(call, nested ? wrapped.extent : wrapped, word, :site)
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
        decides = decisions.each_with_index.flat_map do |decision, i|
          call = "PathCoverage.decide(#{PATH_NAME}, #{i}, "
          tail = decision.exits.nil? ? '' : ", #{decision.exits}"
          command = decision.command
          wrap(call, decision.range, command, :decision, tail)
        end
        [start_insert(site, method)] + decides
      end
    end

    # The insert at method's entry that starts a call's path,
    # outermost of all there.
    def self.start_insert(site, method)
      start = path_start(site, method.decisions.size)
      [method.entry, start, [Float::INFINITY, LAYERS.index(:path)]]
    end

    # The statement that starts a call's path through the
    # method at site, which has size decisions.
    def self.path_start(site, size)
      call = "PathCoverage.path(#{site.inspect}, #{size})"
      "#{PATH_NAME} = #{call}; "
    end

    # The layers of inserts, innermost first, that break a tie
    # between inserts wrapping the same range: a leaf's call, a
    # nested kind's call around its whole, eg end_items, a site's
    # leave, a method's decide, and a method's path start.
    LAYERS = %i[leaf kind site decision path].freeze

    # The two inserts that wrap the code at range in call, with
    # tail as the call's further arguments. Their order, [size,
    # rank], nests them among inserts at the same offset: the
    # longer range outside, the rank of layer in LAYERS breaking
    # a tie. A command call is parenthesised, as it is no bare
    # argument; nothing else is, since parentheses make a
    # statement, which gives its line a line-coverage count of
    # its own.
    def self.wrap(call, range, command, layer, tail = '')
      open, close = command ? ['(', ")#{tail})"] : ['', "#{tail})"]
      order = [range.size, LAYERS.index(layer)]
      [
        [range.begin, call + open, order],
        [range.end, close, order, :close]
      ]
    end

    # Splices each [offset, text, order] insert into source,
    # last offset first so earlier offsets stay valid; a closing
    # insert is marked :close. Text spliced in later at an
    # offset lands before text already there, so at one offset
    # opening inserts go in lowest order first, leaving the
    # highest outermost, then closing ones highest order first,
    # so the innermost call closes first and each tail stays
    # with its own call. Eg a ternary that is a method's
    # decision is a site too: its leave, wrapping the whole
    # ternary, opens outside the decide wrapping its predicate.
    def self.apply(source, inserts)
      sorted = inserts.sort_by do |offset, _, order, close|
        size, rank = order
        close ? [-offset, 1, -size, -rank] : [-offset, 0, size, rank]
      end
      sorted.each do |offset, text, _|
        source.bytesplice(offset, 0, text)
      end
      source
    end
  end
end
