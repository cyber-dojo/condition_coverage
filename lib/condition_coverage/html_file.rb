require 'cgi/escape'
require_relative 'html_template'

module ConditionCoverage
  # One covered file's HTML page: its source, with the numbers
  # of the lines holding a condition as the one button that
  # opens the condition's tree.
  module HtmlFile
    # The whole page for the file at path (relative to root),
    # written at files/<path>.html, so it links back to the
    # index one folder up for each folder in that.
    def self.page(path, lines, trees)
      HtmlTemplate.fill(
        HtmlTemplate.asset('file.html'),
        'path' => CGI.escapeHTML(path),
        'index' => "#{'../' * (path.count('/') + 1)}index.html",
        'style' => HtmlTemplate.asset('style.css'),
        'script' => HtmlTemplate.asset('toggle.js'),
        'listing' => listing(lines, trees)
      )
    end

    # The source listing of lines, as SourceLines.of gives them:
    # each run of lines sharing a span is one block, followed
    # by its hidden tree. trees is { span's first line =>
    # [SiteTree.of, ...] }.
    def self.listing(lines, trees = {})
      blocks = lines.chunk_while do |line, following|
        line[:span] && line[:span] == following[:span]
      end
      body = blocks.map { |block| block(block, trees) }.join("\n")
      %(<div class="code">\n#{body}\n</div>)
    end

    # A plain line, or the lines of one span behind one button
    # with the span's tree straight after them.
    def self.block(lines, trees)
      first = lines[0]
      return plain_line(first) if first[:span].nil?

      number = first[:number]
      site_trees = trees.fetch(number, [])
      span_block(lines, site_trees.size) + tree(number, site_trees)
    end

    # The lines of one span: one button over all their numbers,
    # and how many sites it opens when that is two or more,
    # beside their code.
    def self.span_block(lines, sites)
      numbers = lines.map { |line| number(line[:number]) }.join
      codes = lines.map { |line| code(line) }.join
      srcs = %(<div class="srcs">#{codes}</div>)
      content = site_count(sites) + numbers
      %(<div class="block">#{button(lines[0], content)}#{srcs}</div>)
    end

    # The count of a button's sites, shown only for two or more.
    def self.site_count(sites)
      return '' if sites < 2

      %(<span class="site-count" data-site-count="">#{sites}</span>)
    end

    HEADINGS = %w[condition true false gap].freeze

    # The hidden tree of a span: a heading row, then each site's
    # rows in a group of their own.
    def self.tree(number, site_trees)
      groups = site_trees.map do |site|
        rows = site_rows(site).join
        %(<div class="site" data-site="">#{rows}</div>)
      end
      id = "tree-#{number}"
      body = [heading_row, *groups].join
      %(<div class="tree" id="#{id}" hidden="hidden">#{body}</div>)
    end

    # The row naming each column of a tree.
    def self.heading_row
      cells = HEADINGS.map { |name| %(<span>#{name}</span>) }.join
      %(<div class="row headings" data-heading="">#{cells}</div>)
    end

    # A site's operator row, then one row per operand, each
    # branching from the operator.
    def self.site_rows(site)
      name = CGI.escapeHTML(site[:operator])
      cell = %(<span class="operator" data-operator="">#{name}</span>)
      last = site[:operands].size - 1
      rows = site[:operands].each_with_index.map do |operand, index|
        operand_row(operand, index == last ? '└─ ' : '├─ ')
      end
      [%(<div class="row">#{cell}</div>), *rows]
    end

    # One operand's row: its branch, text, true and false
    # counts, and gap.
    def self.operand_row(operand, branch)
      cells = %i[text truthy falsy gap].map do |name|
        value = CGI.escapeHTML(operand[name].to_s)
        %(<span class="#{name}" data-#{name}="">#{value}</span>)
      end
      lead = %(<span class="branch" data-branch="">#{branch}</span>)
      %(<div class="row" data-operand="">#{lead}#{cells.join}</div>)
    end

    # A line with no condition: its number, then its code.
    def self.plain_line(line)
      %(<div class="line">#{number(line[:number])}#{code(line)}</div>)
    end

    # The closed button over a span's numbers, opening the tree
    # named after its first line.
    def self.button(first, numbers)
      [
        %(<button type="button" class="lnum"),
        %( data-status="#{first[:status]}" aria-expanded="false"),
        %( aria-controls="tree-#{first[:number]}">#{numbers}</button>)
      ].join
    end

    # One line's number.
    def self.number(number)
      %(<span class="lineno" data-line="#{number}">#{number}</span>)
    end

    # One line's code, escaped.
    def self.code(line)
      text = CGI.escapeHTML(line[:text])
      %(<span class="src" data-src="">#{text}</span>)
    end
  end
end
