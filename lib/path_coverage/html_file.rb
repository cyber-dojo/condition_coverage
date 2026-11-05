require 'cgi/escape'
require_relative 'html_mode'
require_relative 'html_nav'
require_relative 'html_syntax'
require_relative 'html_template'
require_relative 'html_tree'

module PathCoverage
  # One covered file's HTML page: its source, with the numbers
  # of the lines holding a condition as the one button that
  # opens the condition's tree.
  module HtmlFile
    # The whole page for the file at path (relative to root),
    # written at files/<path>.html, so it links back to the
    # index one folder up for each folder in that. Measuring
    # methods, its html element names that mode.
    def self.page(path, lines, trees, grids = '', methods: false)
      HtmlTemplate.page(
        'file.html',
        'path' => CGI.escapeHTML(path),
        'mode' => HtmlMode.attribute(methods),
        'index' => "#{'../' * (path.count('/') + 1)}index.html",
        'script' => script,
        'grids' => grids,
        'jumps' => HtmlNav.jumps(lines),
        'listing' => listing(lines, trees)
      )
    end

    # The page's script: its side rails, then its settings and
    # its theme button.
    def self.script
      %w[side.js settings.js theme.js].map do |name|
        HtmlTemplate.asset(name)
      end.join
    end

    # The source listing of lines, as SourceLines.of gives them:
    # each run of lines sharing a span is one block, followed
    # by its hidden tree. trees is { span's first line =>
    # [SiteTree.of, ...] }.
    def self.listing(lines, trees = {})
      blocks = lines.chunk_while do |line, following|
        line[:span] && line[:span] == following[:span]
      end
      gaps = HtmlNav.gap_lines(blocks)
      body = blocks.map { |block| block(block, trees, gaps) }
      %(<div class="code">\n#{body.join("\n")}\n</div>)
    end

    # A plain line, or the lines of one span behind one button
    # with the span's tree straight after them; either way after
    # its nav cell.
    def self.block(lines, trees, gaps)
      first = lines[0]
      number = first[:number]
      cell = HtmlNav.cell(number, gaps)
      return plain_line(first, cell) if first[:span].nil?

      site_trees = trees.fetch(number, [])
      open = first[:status] == :gaps
      span_block(lines, site_trees.size, cell) +
        HtmlTree.of(number, site_trees, open)
    end

    # The lines of one span after their nav cell: one button over
    # all their numbers, and how many sites it opens when that is
    # two or more, beside their code.
    def self.span_block(lines, sites, cell)
      numbers = lines.map { |line| number(line[:number]) }.join
      codes = lines.map { |line| code(line) }.join
      srcs = %(<div class="srcs">#{codes}</div>)
      content = site_count(sites) + numbers
      button = button(lines[0], content)
      %(<div class="block">#{cell}#{button}#{srcs}</div>)
    end

    # The count of a button's sites, shown only for two or more.
    def self.site_count(sites)
      return '' if sites < 2

      %(<span class="site-count" data-site-count="">#{sites}</span>)
    end

    # A line with no condition: its nav cell, number and code.
    def self.plain_line(line, cell)
      parts = cell + number(line[:number]) + code(line)
      %(<div class="line">#{parts}</div>)
    end

    # The button over a span's numbers, toggling the tree named
    # after its first line; expanded when that tree starts open.
    def self.button(first, numbers)
      expanded = first[:status] == :gaps
      [
        %(<button type="button" class="lnum"),
        %( data-status="#{first[:status]}"),
        %( aria-expanded="#{expanded}"),
        %( aria-controls="tree-#{first[:number]}">#{numbers}</button>)
      ].join
    end

    # One line's number, the target of a link to #L<number>.
    def self.number(number)
      attributes = %(id="L#{number}" data-line="#{number}")
      %(<span class="lineno" #{attributes}>#{number}</span>)
    end

    # One line's code, escaped, each of its tokens, if any, in a
    # span of its colour's class.
    def self.code(line)
      text = HtmlSyntax.html(line[:text], line.fetch(:tokens, []))
      %(<span class="src" data-src="">#{text}</span>)
    end
  end
end
