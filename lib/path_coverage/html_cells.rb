require_relative 'kinds'

module PathCoverage
  # The cells of a row of a site's tree on a file's page, one per
  # path. A cell says what its path did: its text a letter, eg T
  # or F, or empty with a mark CSS draws, eg a tick; with text to
  # show on hover when its mark alone may not say enough.
  module HtmlCells
    # [text, mark, hover] of a leaf's or a condition's cell, by
    # the value it took on the path: a letter for each value
    # but a &. receiver's, which is a mark, present or absent,
    # hovering as not nil or nil.
    OUTCOMES = {
      true => ['T'], false => ['F'], nil => [''],
      ITEMS[0] => ['0'], ITEMS[1] => ['1'], ITEMS[2] => ['*'],
      ANSWERS[0] => ['T'], ANSWERS[1] => ['F'], ANSWERS[2] => ['TF'],
      PRESENCE[0] => ['', 'present', PRESENCE[0]],
      PRESENCE[1] => ['', 'absent', PRESENCE[1]]
    }.freeze

    # [text, mark] of a ternary's arm's cell: taken on a path
    # that took it, else blank.
    TAKEN = { true => ['', 'taken'], false => [''] }.freeze

    # [text, mark] of the cell of an arm that returns or raises:
    # leaves on a path that took it, so left the method there,
    # else blank.
    LEAVES = { true => ['', 'leaves'], false => [''] }.freeze

    # The cells of values, each named as names gives it.
    def self.of(values, names = OUTCOMES)
      values.map { |value| cell(*names[value]) }.join
    end

    # One cell: text, and its mark and its hover, when it has
    # them.
    def self.cell(text, mark = nil, hover = nil)
      attrs = +'class="cell" data-cell=""'
      attrs << %( data-mark="#{mark}") if mark
      attrs << %( data-hover="#{hover}") if hover
      %(<span #{attrs}>#{text}</span>)
    end

    # Example: counts 0, 2 and 1284 give 0, * and *.
    # One cell per path: 0 for a path never taken, marked as a
    # gap, * for one taken any number of times, as whether it
    # was taken is what counts; how many times shows on hover,
    # so a count in the thousands never widens the cell.
    def self.counts(counts)
      counts.map do |count|
        css, mark = MARKS[count.zero?]
        hover = times(count)
        %(<span class="#{css}" data-count="" data-hover="#{hover}">) +
          %(#{mark}</span>)
      end.join
    end

    # [class, mark] of a path's count cell, by whether its count
    # is zero.
    MARKS = { true => ['count never', '0'],
              false => ['count', '*'] }.freeze

    # Example: 1 gives 1 time, 1284 gives 1,284 times.
    # How many times a path was taken, as its mark's hover reads
    # it, its thousands apart, so a big count still reads.
    def self.times(count)
      digits = count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
      "#{digits} #{count == 1 ? 'time' : 'times'}"
    end
  end
end
