module PathCoverage
  # What each line of a file's page shows of the methods around
  # it, from its cards, as Card gives them: a method's lines
  # marked for CSS to draw its stripe and band, its def's number
  # marked to open its card, and its body's rows folded under its
  # def line until then. A top card, of sites outside every def,
  # is no method's.
  module HtmlMethods
    # The cards of cards that are methods'.
    def self.of(cards)
      cards.reject(&:top)
    end

    # Example: line 3, f's def at column 2, gives
    # class="src in-method def-line" data-method-status="covered"
    # style="--def-col: 2; --def-end: 15".
    # The attributes of the code of line number, its text text:
    # in a method, its innermost one's status and def's column,
    # marked as its def line, with its text's length, or as its
    # last line when it is; plain in none.
    def self.src_attributes(methods, number, text)
      holders = methods.select { |card| card.holds?(number) }
      return 'class="src"' if holders.empty?

      inner = holders.max_by(&:first)
      css = ['src', 'in-method', *marks(methods, number)].join(' ')
      style = "--def-col: #{inner.column}"
      style += "; --def-end: #{text.length}" if inner.first == number
      %(class="#{css}" data-method-status="#{inner.status}") +
        %( style="#{style}")
    end

    # The marks of a line that is some method's first or last.
    def self.marks(methods, number)
      firsts = methods.map(&:first)
      lasts = methods.map(&:last)
      [('def-line' if firsts.include?(number)),
       ('method-end' if lasts.include?(number))].compact
    end

    # The attributes a def's number adds, opening its method's
    # card, which starts closed: none on any other line.
    def self.number_attributes(methods, number)
      card = methods.find { |each| each.first == number }
      return 'class="lineno"' unless card

      closed = 'aria-expanded="false"'
      %(class="lineno mdef" data-status="#{card.status}" #{closed})
    end

    # True when line number's row starts folded: in a method's
    # body, after its def line. A row in a method is one line, so
    # a def line's row is never folded under its own def.
    def self.folded?(methods, number)
      methods.any? do |card|
        ((card.first + 1)..card.last).cover?(number)
      end
    end

    # True when line number is in no method, so its site's button
    # opens its lines' top card.
    def self.loose?(methods, number)
      methods.none? { |card| card.holds?(number) }
    end
  end
end
