require_relative 'html_cards'
require_relative 'html_statements'
require_relative 'method_statements'
require_relative 'source_lines'

module PathCoverage
  # What is measured within each method of a covered file.
  module WithinMethods
    # Where each statement of the covered file at path, parsed
    # as Manifest.parse gives it, that is no site is reached, as
    # MethodStatements.reaches gives them.
    def self.reaches(path, parsed, config)
      source, sites = parsed.values_at(:source, :sites)
      MethodStatements.reaches(source, config.relative(path), sites)
    end

    # Example: { "k.rb:0:0" => [1, 2], "k.rb:1:0" => [2, 4] }.
    # Each def's card total, [taken, size], in every file in
    # files, { full path => {source:, sites:} }, from paths, as
    # Result#paths gives them, and reached, as Recorder#reached
    # does; and each file's top level's, its sites on no card,
    # named for line 0, which no def is on.
    def self.cards(files, config, paths, reached)
      files.map do |full_path, parsed|
        path = config.relative(full_path)
        source, sites = parsed.values_at(:source, :sites)
        top = MethodStatements.top_level(source, path, paths, sites)
        MethodStatements.totals(source, path, paths, reached, sites)
                        .merge("#{path}:0:0" => top)
      end.reduce({}, :merge)
    end

    # Example: { "k.rb:1:0" => { "name" => "ship", "first" => 1,
    # "last" => 3, "rows" => [{ "at" => "2:04", ... }] } }.
    # Each card in every file in files, a def's and a top card's,
    # as its page draws it, for the JSON report, so a reader
    # finds a card's gap without the page; result a Result,
    # reached as cards takes it.
    def self.listed(files, config, result, reached)
      files.map do |full_path, parsed|
        path = config.relative(full_path)
        listed_in(path, parsed, result.paths, reached)
          .merge(listed_tops(path, parsed, result))
      end.reduce({}, :merge)
    end

    # The top cards of the file at path, as its page draws them:
    # each under the site of its first line's start, named for
    # its scope, as listed gives them.
    def self.listed_tops(path, parsed, result)
      source, sites = parsed.values_at(:source, :sites)
      lines = SourceLines.of(source, sites, result.operands)
      scopes = HtmlCards.scopes(source)
      HtmlCards.spans(path, parsed, lines).to_h do |span, rows|
        site = "#{path}:#{span.begin}:0"
        taken = rows.zip(MethodStatements.taken(rows, result.paths))
        [site, card(site, scopes[span.begin], span.end, taken)]
      end
    end

    # The cards of the file at path, parsed as Manifest.parse
    # gives it, as listed gives them.
    def self.listed_in(path, parsed, paths, reached)
      source, sites = parsed.values_at(:source, :sites)
      names = MethodStatements.names(source, path, sites)
      lasts = MethodStatements.lasts(source, path, sites)
      MethodStatements.of(source, path, sites).to_h do |site, rows|
        taken = MethodStatements.taken(rows, paths, reached)
        [site, card(site, names[site], lasts[site], rows.zip(taken))]
      end
    end

    # The card of the def at site named name, ending on line
    # last: its first line, from site, and a row for each
    # [statement, taken] of rows.
    def self.card(site, name, last, rows)
      first = Integer(site.split(':')[-2])
      listed = rows.map { |statement, count| row(statement, count) }
      { 'name' => name, 'first' => first, 'last' => last,
        'rows' => listed }
    end

    # A card's row: statement's line:column, as its page labels
    # it, its top, its paths, count, how many were taken, and
    # its site, nil for a statement that is no site.
    def self.row(statement, count)
      { 'at' => HtmlStatements.label(statement),
        'top' => statement.top, 'paths' => statement.paths,
        'taken' => count, 'site' => statement.site }
    end
  end
end
