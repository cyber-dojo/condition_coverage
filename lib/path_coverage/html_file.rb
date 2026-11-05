require 'cgi/escape'
require_relative 'card'
require_relative 'html_methods'
require_relative 'html_nav'
require_relative 'html_syntax'
require_relative 'html_template'

module PathCoverage
  # One covered file's HTML page: its source beside the rail of
  # its cards, as Card gives them, one open at a time. A method's
  # def number opens its card; a site outside every method has
  # one button over its lines' numbers that opens their top card.
  module HtmlFile
    # The whole page for the file at path (relative to root),
    # written at files/<path>.html, so it links back to the
    # index one folder up for each folder in that.
    def self.page(path, lines, cards = [])
      HtmlTemplate.page(
        'file.html',
        'path' => CGI.escapeHTML(path),
        'index' => "#{'../' * (path.count('/') + 1)}index.html",
        'script' => script,
        'rail' => cards.map(&:html).join("\n"),
        'jumps' => HtmlNav.jumps(cards),
        'listing' => listing(lines, cards)
      )
    end

    # The page's script: its rail's behaviour, then its settings
    # and its theme button.
    def self.script
      %w[side.js settings.js theme.js].map do |name|
        HtmlTemplate.asset(name)
      end.join
    end

    # The source listing of lines, as SourceLines.of gives them,
    # marked with the methods of cards: a row per line, but one
    # row over all the lines of a site outside every method.
    def self.listing(lines, cards = [])
      methods = HtmlMethods.of(cards)
      tops = cards.select(&:top).to_h { |card| [card.first, card] }
      rows = lines.chunk { |line| row_key(line, methods) }
      body = rows.map do |key, row|
        next line(row[0], cards, methods) unless key.is_a?(Range)

        loose_block(row, cards, tops[key.begin])
      end
      %(<div class="code">\n#{body.join("\n")}\n</div>)
    end

    # The span of line's site when it is outside every method, so
    # its lines share one row; else line's own number.
    def self.row_key(line, methods)
      span = line[:span]
      loose = span && HtmlMethods.loose?(methods, span.begin)
      loose ? span : line[:number]
    end

    # A line of its own, after its gutter, folded when it is in a
    # method's body.
    def self.line(line, cards, methods)
      number = line[:number]
      cell = HtmlNav.cell([number], cards)
      folded = HtmlMethods.folded?(methods, number)
      css = folded ? 'line method-folded' : 'line'
      parts = number(number, methods) + code(line, methods)
      %(<div class="#{css}">#{cell}#{parts}</div>)
    end

    # The lines of a site outside every method after their gutter:
    # one button over all their numbers, opening their top card,
    # top, and how many sites it opens when that is two or more,
    # beside their code.
    def self.loose_block(lines, cards, top)
      numbers = lines.map { |line| line[:number] }
      cell = HtmlNav.cell(numbers, cards)
      spans = numbers.map { |number| number(number, []) }.join
      button = button(lines[0], top, site_count(top) + spans)
      srcs = lines.map { |line| code(line, []) }.join
      %(<div class="block">#{cell}#{button}) +
        %(<div class="srcs">#{srcs}</div></div>)
    end

    # The count of a top card's sites, shown only for two or more.
    def self.site_count(top)
      sites = top ? top.sites : 0
      return '' if sites < 2

      %(<span class="site-count" data-site-count="">#{sites}</span>)
    end

    # The button over a loose site's numbers, wearing its top
    # card's status, else its first line's, closed until its card
    # opens.
    def self.button(first, top, numbers)
      status = top ? top.status : first[:status]
      [
        %(<button type="button" class="lnum loose"),
        %( data-status="#{status}" aria-expanded="false"),
        %( aria-controls="paths-#{first[:number]}">),
        numbers, '</button>'
      ].join
    end

    # One line's number, the target of a link to #L<number>; a
    # def's marked to open its method's card.
    def self.number(number, methods)
      css = HtmlMethods.number_attributes(methods, number)
      attributes = %(#{css} id="L#{number}" data-line="#{number}")
      %(<span #{attributes}>#{number}</span>)
    end

    # One line's code, escaped, each of its tokens, if any, in a
    # span of its colour's class, marked with its methods.
    def self.code(line, methods)
      number, plain = line.values_at(:number, :text)
      text = HtmlSyntax.html(plain, line.fetch(:tokens, []))
      css = HtmlMethods.src_attributes(methods, number, plain)
      %(<span #{css} data-src="">#{text}</span>)
    end
  end
end
