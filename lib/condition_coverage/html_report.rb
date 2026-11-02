require 'fileutils'
require_relative 'html_file'
require_relative 'html_index'
require_relative 'html_paths'
require_relative 'path_manifest'
require_relative 'site_tree'
require_relative 'source_lines'
require_relative 'summary'

module ConditionCoverage
  # The :html reporter: index.html, and files/<path>.html for
  # each covered file, written to the configuration's
  # output_dir.
  module HtmlReport
    # Writes every page. operands and outcomes are as Result
    # gives them; files is { full path => {source:, sites:} }
    # for each covered file, as the kernel parsed it.
    def self.write(
      operands, files, config, paths = nil, outcomes = {}
    )
      dir = config.output_dir
      index = HtmlIndex.page(Summary.files(operands))
      File.write("#{dir}/index.html", index)
      files.each do |full_path, parsed|
        path = config.relative(full_path)
        out = "#{dir}/files/#{path}.html"
        grids = paths ? path_grids(path, parsed, paths) : ''
        counts = { operands:, outcomes: }
        write_page(out, path, parsed, counts, grids)
      end
    end

    # SPIKE: the hidden path grids of one file's methods.
    def self.path_grids(path, parsed, paths)
      source = parsed[:source]
      methods = PathManifest.methods(source, path)
      HtmlPaths.grids(source, methods, paths)
    end

    # Writes one file's page to out. counts is { operands:,
    # outcomes: }, as Result gives them.
    def self.write_page(out, path, parsed, counts, grids = '')
      source, sites = parsed.values_at(:source, :sites)
      lines = SourceLines.of(source, sites, counts[:operands])
      trees = trees(source, sites, lines, counts)
      FileUtils.mkdir_p(File.dirname(out))
      File.write(out, HtmlFile.page(path, lines, trees, grids))
    end

    # { first line of a span => [SiteTree.of, ...] } for the
    # sites of one file, each under the span its line is in,
    # each root with its site's own outcome when there is one.
    def self.trees(source, sites, lines, counts)
      trees = Hash.new { |all, first| all[first] = [] }
      sites.each do |site, condition|
        first = lines[SourceLines.line_of(site) - 1][:span].begin
        tree = tree_of(source, site, condition, counts)
        trees[first] << located(source, condition, tree)
      end
      trees
    end

    # The SiteTree of one site, with its operands' counts and
    # its own outcome's.
    def self.tree_of(source, site, condition, counts)
      operands = counts[:operands].fetch(site)
      outcome = counts[:outcomes][site]
      SiteTree.of(source, condition, operands, outcome)
    end

    # SPIKE: tree with an at: of [line, column, line, column]
    # on it and on each of its operands: a leaf's from its byte
    # range, a condition's from its extent, the whole of it as
    # written. Columns count characters, not bytes.
    def self.located(source, condition, tree)
      operands = condition.operands.zip(tree[:operands]).map do |operand, node|
        next located(source, operand, node) if operand.is_a?(Condition)

        node.merge(at: at(source, operand))
      end
      tree.merge(at: at(source, condition.extent), operands:)
    end

    # [line, column, line, column] of the byte range in source.
    def self.at(source, range)
      [*position(source, range.begin), *position(source, range.end)]
    end

    # [line, column] of a byte offset in source.
    def self.position(source, offset)
      before = source.byteslice(0, offset)
      newline = before.rindex("\n")
      [before.count("\n") + 1, before.length - (newline ? newline + 1 : 0)]
    end
  end
end
