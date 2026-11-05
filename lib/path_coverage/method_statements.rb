require 'prism'
require_relative 'manifest'
require_relative 'manifest_chains'
require_relative 'manifest_choices'
require_relative 'site'
require_relative 'site_paths'
require_relative 'statement_arms'

module PathCoverage
  # One row of a method's popout, a top-level statement or a
  # site at its top: where it starts; its top, what it is as
  # written, eg = for a write; how many paths it has; the name
  # of its site, nil when it is no site; and its own name, by
  # where it is, eg "k.rb:2:2".
  Statement = Data.define(:line, :column, :top, :paths, :site, :name)

  # Finds, without running it, the top-level statements of each
  # method in source, one row each in its method-mode popout.
  module MethodStatements
    # Each function below takes sites, { site => Condition }, the
    # sites the run has in source, as Manifest.parse gives them
    # with the run's ignore and treat settings; nil for those of
    # no settings.

    # { def site => [Statement, ...] } for each def in source.
    # Example: def f; x = 1; x; end gives = and value rows.
    def self.of(source, path, sites = nil)
      collect(source, path, sites).methods
    end

    # { def site => its name } for each def in source, eg
    # { "k.rb:4:2" => :ship }, each its card's title.
    def self.names(source, path, sites = nil)
      collect(source, path, sites).names
    end

    # { def site => its last line } for each def in source, eg
    # { "k.rb:4:2" => 6 }, where its card ends.
    def self.lasts(source, path, sites = nil)
      collect(source, path, sites).lasts
    end

    # Example: { "k.rb:2:2" => 18 } for a write at byte 18.
    # Where a call can count the runs of each row that is no
    # site, in every def in source, by the row's name, where it
    # starts: its byte offset, or, in an endless def, whose body
    # is one expression, its byte range, to be wrapped.
    def self.reaches(source, path, sites = nil)
      collect(source, path, sites).reaches
    end

    # A Collector that has visited each def in source, with
    # sites, or, for nil, those of no settings.
    def self.collect(source, path, sites)
      known = sites || Manifest.sites(source, path)
      collector = Collector.new(path, known)
      Prism.parse(source).value.accept(collector)
      collector
    end

    # Example: { "k.rb:1:0" => [2, 4] }, 2 of ship's 4 taken.
    # Each def's card total in source, [taken, size], its rows'
    # taken as taken gives them from paths and reached; a row
    # not known counts as not taken, never more than it ran.
    def self.totals(source, path, paths, reached, sites = nil)
      of(source, path, sites).transform_values do |rows|
        [taken(rows, paths, reached).compact.sum, size(rows)]
      end
    end

    # Example: rows with 1, 2 and 2 paths have size 5.
    # The paths a method's tests are to take: its rows' paths
    # added up, each row's taken on its own.
    def self.size(rows)
      rows.sum(&:paths)
    end

    # Example: rows with 1, 2 and 2 paths have complexity 4.
    # The paths through a method as a whole: its rows' paths
    # multiplied, as each path of one row goes on to each of
    # the next.
    def self.complexity(rows)
      rows.map(&:paths).reduce(1, :*)
    end

    # Example: an if row with only its then taken gives 1.
    # How many paths of each row were taken: for a site's row,
    # its paths with a count, paths being Result#paths; for any
    # other row, its 1 path when reached has a count for it, 0
    # when not, nil, not known, without reached.
    def self.taken(rows, paths, reached = nil)
      rows.map do |row|
        next taken_site(row, paths) if row.site
        next nil if reached.nil?

        reached.key?(row.name) ? 1 : 0
      end
    end

    # How many of a site row's paths have a count in paths.
    def self.taken_site(row, paths)
      paths.fetch(row.site).count { |each| each[:count].positive? }
    end

    # Collects each def's top-level statements.
    class Collector < Prism::Visitor
      include ManifestChains
      include ManifestChoices
      include StatementArms

      # Starts with no methods found; sites are decision mode's,
      # { site => Condition }.
      def initialize(path, sites)
        @path = path
        @sites = sites
        @methods = {}
        @names = {}
        @lasts = {}
        @reaches = {}
        super()
      end

      # The methods found so far, { def site => rows }; their
      # names and last lines, { def site => name } and { def site
      # => line }; and where each row that is no site is reached,
      # as MethodStatements.reaches has it.
      attr_reader :methods, :names, :lasts, :reaches

      # Notes node's name, its last line, its body statements as
      # its rows, those in its sites' arms too, none for an empty
      # body, and where each row that is no site is reached.
      def visit_def_node(node)
        tops = rows_in(statements_of(node.body))
        site = Site.of(@path, node)
        @methods[site] = tops.map { |top| row_of(top) }
        note_def(site, node)
        note_reaches(tops, endless: !node.equal_loc.nil?)
        super
      end

      # Notes the name and last line of node, the def at site.
      def note_def(site, node)
        @names[site] = node.name
        @lasts[site] = node.location.end_line
      end

      # Notes where each of tops that is no site is reached: its
      # byte offset, or, endless, its byte range.
      def note_reaches(tops, endless:)
        tops.reject { site?(_1) }.each do |top|
          loc = top.location
          start = loc.start_offset
          at = endless ? start...loc.end_offset : start
          @reaches[Site.at(@path, loc)] = at
        end
      end

      # Example: if a then x = 1 end gives the if, then the write.
      # The nodes statements' rows are for, flat, in the order
      # they are written: each statement's tops, each followed by
      # the sites of their own inside it, then the rows of its
      # arms' statements, when it has any.
      def rows_in(statements)
        statements.flat_map do |statement|
          tops = top_nodes(statement).flat_map do |top|
            [top, *inner_sites(top), *rows_in(arms_of(top))]
          end
          tops + body_rows(statement)
        end
      end

      # The Statement row of node. A site is where decision mode
      # names it, eg a modifier if at its keyword, with as many
      # paths as decision mode gives it. Anything else is where
      # it starts, with 1 path.
      def row_of(node)
        site = site_at(node)
        loc = site ? site_loc(node) : node.location
        name = Site.at(@path, loc)
        Statement.new(
          line: loc.start_line, column: loc.start_column,
          top: top_of(node),
          paths: site ? SitePaths.possible(site).size : 1,
          site: site ? name : nil, name:
        )
      end

      # Example: x = (a ? 1 : 2) + (b ? 3 : 4) gives both ?:s.
      # The nodes statement's rows are for: the outermost sites
      # in it, in the order they run, as what holds them is
      # looked through; statement itself when it holds none.
      def top_nodes(statement)
        tops = sites_in(statement)
        tops.empty? ? [statement] : tops
      end

      # node when it is a site, else the outermost sites in its
      # children, in order; none in a body or a def, as UNSEEN
      # has them.
      def sites_in(node)
        return [node] if site?(node)
        return [] if UNSEEN.include?(node.type)

        node.compact_child_nodes.flat_map { |child| sites_in(child) }
      end

      # True when decision mode has a site named where node's
      # site would start.
      def site?(node)
        !site_at(node).nil?
      end

      # Decision mode's Condition for the site named where
      # node's site would start; nil when it has none there.
      def site_at(node)
        @sites[site_name(node)]
      end

      # The name node's site would have, by where it would start.
      def site_name(node)
        Site.at(@path, site_loc(node))
      end

      TOPS = {
        call_node: '()', return_node: 'return', def_node: 'def'
      }.freeze

      # What statement is as written: a site's operator, eg if,
      # when decision mode has a site where it starts, an elsif
      # being elsif, as written; else = for a write, () for a
      # call, raise for a raise of the method's own, as it leaves
      # the method, return for a return, def for a def inside it,
      # value for anything else.
      def top_of(statement)
        site = site_at(statement)
        return 'elsif' if site && elsif?(statement)
        return site.operator if site
        return 'raise' if raise?(statement)
        return '=' if write?(statement)

        TOPS.fetch(statement.type, 'value')
      end

      # True for an if written as an elsif.
      def elsif?(statement)
        statement.type == :if_node && statement.if_keyword == 'elsif'
      end

      # True for a write of any kind: of a variable, eg @x = 1
      # or x += 1, or a call Ruby makes of an index or attribute
      # write, eg a[i] = x or a.b = x.
      def write?(statement)
        statement.type.end_with?('_write_node') ||
          (statement.type == :call_node && statement.attribute_write?)
      end

      # True when statement is a call of raise with no receiver.
      def raise?(statement)
        statement.type == :call_node && statement.receiver.nil? &&
          statement.name == :raise
      end
    end
  end
end
