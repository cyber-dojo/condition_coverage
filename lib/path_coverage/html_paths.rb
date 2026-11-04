require 'cgi/escape'
require 'prism'
require_relative 'path_gaps'

module PathCoverage
  # SPIKE: the path grids of one covered file's page, hidden in
  # the page until side.js moves them into the rail. Each grid
  # has a row per decision, to sit level with that decision's
  # line, and a column per possible path, never-taken first.
  module HtmlPaths
    # The hidden grids of every method in methods.
    def self.grids(source, methods, paths)
      ends = end_lines(source)
      arms = arm_lines(source)
      methods.map do |site, method|
        grid(site, method, paths.fetch(site, {}), ends, arms)
      end.join("\n")
    end

    # { an if's first line => its parts' lines } for every if:
    # head, its if and predicate; then, its then arm; else, its
    # else (or elsif) keyword through its arm; end, its end line.
    # Each is [first, last], nil when absent; a modifier if or
    # ternary is all head.
    def self.arm_lines(source)
      arms = {}
      walk = lambda do |node|
        arms[node.location.start_line] = if_parts(node) if node.type == :if_node
        node.compact_child_nodes.each { |child| walk.call(child) }
      end
      walk.call(Prism.parse(source).value)
      arms
    end

    # The lines of an if's parts, as arm_lines gives them.
    def self.if_parts(node)
      start = node.location.start_line
      return { head: [start, start] } if node.end_keyword_loc.nil?

      last = node.end_keyword_loc.start_line
      then_arm = span(node.statements)
      else_part = else_lines(node.subsequent, last)
      body = [then_arm&.first, else_part&.first, last].compact.min
      {
        head: [start, [start, body - 1].max], then: then_arm,
        else: else_part, end: [last, last]
      }
    end

    # The lines from an else or elsif keyword to the end of its
    # arm, the line before the if's end for an elsif.
    def self.else_lines(otherwise, last)
      return nil if otherwise.nil?
      return [otherwise.location.start_line, last - 1] if otherwise.type == :if_node

      first = otherwise.else_keyword_loc.start_line
      [first, otherwise.statements ? otherwise.statements.location.end_line : first]
    end

    # The first and last lines of statements, nil for none.
    def self.span(statements)
      return nil if statements.nil?

      loc = statements.location
      [loc.start_line, loc.end_line]
    end

    # { def's first line => its last line } for every def.
    def self.end_lines(source)
      ends = {}
      walk = lambda do |node|
        if node.type == :def_node
          loc = node.location
          ends[loc.start_line] = loc.end_line
        end
        node.compact_child_nodes.each { |child| walk.call(child) }
      end
      walk.call(Prism.parse(source).value)
      ends
    end

    # One method's grid: its calls row, level with its def, then
    # a row per decision, level with that decision's line.
    def self.grid(site, method, taken, ends, arms)
      first = site.split(':')[-2].to_i
      every = PathGaps.possible(method.decisions)
      ordered = every.each_with_index.sort_by do |path, i|
        [taken.key?(path) ? 1 : 0, i]
      end.map(&:first)
      missing = every.count { |path| !taken.key?(path) }
      status = missing.zero? ? 'covered' : 'gaps'
      rows = [calls_row(first, ordered, taken, method, every.size - missing)]
      method.decisions.each_with_index do |decision, i|
        rows << decision_row(decision, i, ordered, taken, arms)
      end
      attrs = [
        %(id="paths-#{first}" data-first="#{first}"),
        %(data-col="#{site.split(':').last}"),
        %(data-last="#{ends.fetch(first, first)}" data-status="#{status}")
      ].join(' ')
      %(<div class="pathgrid" #{attrs} hidden="hidden">#{rows.join}</div>)
    end

    # The row level with the def: how many calls took each path,
    # never-taken ones marked. Its label cell is empty, keeping
    # the columns level with the decision rows' labelled ones.
    def self.calls_row(first, ordered, taken, method, seen)
      cells = ordered.map do |path|
        calls = taken.fetch(path, 0)
        css = calls.zero? ? 'pcell never' : 'pcell taken'
        %(<span class="#{css}">#{calls.zero? ? '0' : calls}</span>)
      end
      name = CGI.escapeHTML(method.name.to_s)
      label = '<span class="plabel"></span>'
      title = %( title="#{name}: #{seen} of #{ordered.size} paths taken")
      %(<div class="prow calls" data-line="#{first}"#{title}>#{label}#{cells.join}</div>)
    end

    # The row level with a decision: T or F for each path that
    # makes it, those of never-taken paths marked, blank for a
    # path that ended before it.
    def self.decision_row(decision, index, ordered, taken, arms)
      cells = ordered.map do |path|
        outcome = path[index]
        next '<span class="pcell ended"></span>' if outcome.nil?

        never = taken.key?(path) ? '' : ' never'
        %(<span class="pcell #{outcome}#{never}">#{outcome ? 'T' : 'F'}</span>)
      end
      label = %(<span class="plabel">#{decision.line}</span>)
      arm = arms.fetch(decision.line, {})
      parts = %i[head then else end].map do |part|
        %(data-#{part}="#{arm[part]&.join(',')}")
      end
      data = [%(data-line="#{decision.line}"), *parts].join(' ')
      %(<div class="prow" #{data}>#{label}#{cells.join}</div>)
    end
  end
end
