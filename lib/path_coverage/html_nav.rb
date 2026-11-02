module PathCoverage
  # The ways around a file's page: the header's lists of links to
  # each span, and the arrows between the spans with gaps.
  module HtmlNav
    JUMP_LISTS = { 'covered' => 'Covered', 'gaps' => 'Gaps' }.freeze

    # The header's lists of links to the first line of each span:
    # those covered, then those with gaps.
    def self.jumps(lines)
      firsts = lines.select { |line| first_of_span?(line) }
      lists = JUMP_LISTS.map do |status, label|
        spans = firsts.select { |line| line[:status].to_s == status }
        jump_list(status, label, spans.map { |line| line[:number] })
      end
      %(<nav class="jumps" aria-label="Sites">#{lists.join}</nav>)
    end

    # True for the line a span starts on.
    def self.first_of_span?(line)
      line[:span]&.begin == line[:number]
    end

    # One labelled list of links to lines.
    def self.jump_list(status, label, numbers)
      links = numbers.map { |number| jump(status, number) }
      name = %(<span class="jump-label">#{label}</span>)
      list = %(<div class="jump-list" data-jumps="#{status}">)
      "#{list}#{name}#{links.join}</div>"
    end

    # One link to a line.
    def self.jump(status, number)
      attributes = %(data-status="#{status}" href="#L#{number}")
      %(<a class="jump" #{attributes}>#{number}</a>)
    end

    # The first line of each span whose sites have gaps, given the
    # listing's blocks.
    def self.gap_lines(blocks)
      firsts = blocks.map(&:first)
      firsts.select { |line| line[:status] == :gaps }.map do |line|
        line[:number]
      end
    end

    # The cell left of a row's number: at a span with gaps, links
    # to the previous and next such span, wrapping round at the
    # ends; empty on every other row, so the numbers stay aligned.
    def self.cell(number, gaps)
      index = gaps.index(number)
      links = index ? arrows(gaps, index) : ''
      %(<span class="nav" data-nav="">#{links}</span>)
    end

    # The links to the spans with gaps either side of gaps[index].
    def self.arrows(gaps, index)
      previous = gaps[index - 1]
      following = gaps[(index + 1) % gaps.size]
      [
        %(<a data-prev="" href="#L#{previous}"),
        %( aria-label="Previous gap, line #{previous}">&#9650;</a>),
        %(<a data-next="" href="#L#{following}"),
        %( aria-label="Next gap, line #{following}">&#9660;</a>)
      ].join
    end
  end
end
