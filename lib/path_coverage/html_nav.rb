module PathCoverage
  # The ways around a file's page, from its cards, as Card gives
  # them: the header's row of jumps to each card with gaps, and
  # the arrows in the gutter between the cards of each status.
  module HtmlNav
    # Each status's arrows, gaps first, and how a label names it.
    KINDS = { 'gaps' => 'with gaps', 'covered' => 'covered' }.freeze

    # The header's row of jumps, labelled Gaps, to the first line
    # of each card with gaps, in line order; marked empty when
    # there are none, so the header keeps its height.
    def self.jumps(cards)
      firsts = firsts(cards, 'gaps')
      links = firsts.map { |first| jump(first) }
      empty = links.empty? ? ' data-empty=""' : ''
      name = '<span class="jump-label">Gaps</span>'
      list = %(<div class="jump-list"#{empty}>#{name}#{links.join})
      %(<nav class="jumps" aria-label="Cards">#{list}</div></nav>)
    end

    # One jump to a card with gaps at line first.
    def self.jump(first)
      attributes = %(data-status="gaps" href="#L#{first}")
      %(<a class="jump" #{attributes}>#{first}</a>)
    end

    # The first lines of the cards of status, in line order.
    def self.firsts(cards, status)
      cards.select { |card| card.status == status }.map(&:first).sort
    end

    # The gutter of the row of numbers: by each card's first line,
    # an arrow to the card of its status before it, and one to the
    # one after, wrapping round at either end; empty on every
    # other row, so the numbers stay aligned.
    def self.cell(numbers, cards)
      links = KINDS.keys.flat_map do |status|
        firsts = firsts(cards, status)
        (firsts & numbers).flat_map do |first|
          arrows(firsts, first, status)
        end
      end
      %(<span class="nav" data-nav="">#{links.join}</span>)
    end

    # The arrows by the card of status at line first to those
    # either side of it in firsts, the first lines of the cards of
    # its status.
    def self.arrows(firsts, first, status)
      index = firsts.index(first)
      following = firsts[(index + 1) % firsts.size]
      [arrow('prev', firsts[index - 1], status),
       arrow('next', following, status)]
    end

    # Each arrow's way and how its label names it.
    WAYS = { 'prev' => 'Previous', 'next' => 'Next' }.freeze

    # One arrow, way prev or next, to the card of status at line;
    # CSS draws its glyph, in its status's colour.
    def self.arrow(way, line, status)
      label = "#{WAYS[way]} card #{KINDS[status]}, line #{line}"
      %(<a data-#{way}="" data-status="#{status}" href="#L#{line}") +
        %( aria-label="#{label}"></a>)
    end
  end
end
