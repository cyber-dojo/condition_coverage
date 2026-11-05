require_relative 'card'
require_relative 'html_statements'
require_relative 'html_tree'
require_relative 'method_statements'
require_relative 'site_tree'

module PathCoverage
  # The cards of one file's page, as Card gives them, in the rail
  # beside its code: a card for each of its methods, and one for
  # each span of its lines holding sites at the top level; each
  # site's row with its tree folded under it. It relies on
  # HtmlReport.located to place each tree's rows in the source.
  module HtmlCards
    # The cards of each method of the file at path, parsed as
    # Manifest.parse gives it; site_paths as Result#paths gives
    # them, reached as Recorder#reached does.
    def self.methods(path, parsed, (site_paths, reached))
      source, sites = parsed.values_at(:source, :sites)
      names = MethodStatements.names(source, path, sites)
      lasts = MethodStatements.lasts(source, path, sites)
      tree = ->(at) { fold(source, sites, site_paths, at) }
      MethodStatements.of(source, path, sites).map do |site, rows|
        taken = MethodStatements.taken(rows, site_paths, reached)
        named = [names[site], lasts[site]]
        method_card(site, named, rows, taken, &tree)
      end
    end

    # The Card of the def at site named name, ending on line last,
    # its rows' taken as taken gives them.
    def self.method_card(site, (name, last), rows, taken, &)
      html = HtmlStatements.card(site, name, rows, taken, last, &)
      first, column = site.split(':').last(2).map { Integer(_1) }
      status = HtmlStatements.status(rows, taken)
      Card.new(first:, last:, column:, status:, top: false,
               sites: nil, html:)
    end

    # A top card for each span of lines holding sites at the top
    # level of the file at path, outside every def, as each
    # span's lines share one button: a row per site in it. lines
    # are as SourceLines.of gives them.
    def self.tops(path, parsed, lines, site_paths)
      source, sites = parsed.values_at(:source, :sites)
      tree = ->(at) { fold(source, sites, site_paths, at) }
      scopes = scopes(source)
      spans(path, parsed, lines).map do |span, rows|
        top(path, span, rows, site_paths, scopes[span.begin], &tree)
      end
    end

    # The top card of the span of lines of the file at path,
    # holding rows, titled scope.
    def self.top(path, span, rows, site_paths, scope, &)
      taken = MethodStatements.taken(rows, site_paths)
      site = "#{path}:#{span.begin}:0"
      html = HtmlStatements.top_card(site, scope, rows, taken,
                                     span.end, &)
      Card.new(first: span.begin, last: span.end, column: 0,
               status: HtmlStatements.status(rows, taken), top: true,
               sites: rows.size, html:)
    end

    # A lambda giving the scope of a line of source, as scope
    # gives it, its modules and classes found once.
    def self.scopes(source)
      holders = holders_in(Prism.parse(source).value)
      ->(line) { scope(holders, line) }
    end

    # Example: line 2, inside module Shop on lines 1 to 9, gives
    # Shop.
    # The name of the innermost of holders, modules and classes,
    # whose lines hold line, a top card's scope, as a def is a
    # method card's; file for a line in none.
    def self.scope(holders, line)
      holding = holders.select do |node|
        location = node.location
        (location.start_line..location.end_line).cover?(line)
      end
      holding.empty? ? 'file' : holding.last.name.to_s
    end

    # The kinds of node that are a top card's scope.
    HOLDERS = [Prism::ModuleNode, Prism::ClassNode].freeze

    # Every module and class node in the tree at node, each
    # before those nested in it.
    def self.holders_in(node)
      own = HOLDERS.include?(node.class) ? [node] : []
      own + node.compact_child_nodes.flat_map { holders_in(_1) }
    end

    # { span => its top-level rows } of the file at path, each
    # row under the span its line is in.
    def self.spans(path, parsed, lines)
      source, sites = parsed.values_at(:source, :sites)
      rows = MethodStatements.top_rows(source, path, sites)
      rows.group_by { lines[_1.line - 1][:span] }
    end

    # The rows of site's tree, as a file's page draws them, for
    # its row's fold in a card.
    def self.fold(source, sites, site_paths, site)
      condition = sites.fetch(site)
      tree = SiteTree.of(source, condition, site_paths.fetch(site))
      located = HtmlReport.located(source, condition, tree)
      HtmlTree.site_rows(located).join
    end
  end
end
