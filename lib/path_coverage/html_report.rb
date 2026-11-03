require 'fileutils'
require_relative 'html_file'
require_relative 'html_index'
require_relative 'html_paths'
require_relative 'path_manifest'
require_relative 'site_tree'
require_relative 'source_lines'
require_relative 'summary'

module PathCoverage
  # The :html reporter: index.html, and files/<path>.html for
  # each covered file, written to the configuration's
  # output_dir.
  module HtmlReport
    # Writes every page. operands and site_paths are as Result
    # gives them, site_paths holding every site in files; files
    # is { full path => {source:, sites:} } for each covered
    # file, as the kernel parsed it.
    def self.write(operands, files, config, paths = nil, site_paths:)
      dir = config.output_dir
      index = index(files, config, paths, site_paths)
      File.write("#{dir}/index.html", index)
      files.each do |full_path, parsed|
        path = config.relative(full_path)
        out = "#{dir}/files/#{path}.html"
        # simplecov:disable
        grids = paths ? path_grids(path, parsed, paths) : ''
        # simplecov:enable
        write_page(out, path, parsed, [operands, site_paths], grids)
      end
    end

    # The index page: a row per file of its totals within each
    # decision, and, when paths are given, as they are when
    # methods are measured, across each method's decisions too;
    # then their Total row. With groups configured, each group,
    # and the files in none, get a tab of their own too.
    def self.index(files, config, paths, site_paths)
      methods = files.map do |full_path, parsed|
        path = config.relative(full_path)
        PathManifest.methods(parsed[:source], path)
      end
      all = methods.reduce({}, :merge)
      rows = Summary.files(site_paths, all, paths)
      groups = config.groups
      tabs = groups.empty? ? [] : Summary.groups(rows, groups)
      HtmlIndex.page(rows, Summary.total(rows), tabs)
    end

    # simplecov:disable
    # SPIKE: the hidden path grids of one file's methods.
    def self.path_grids(path, parsed, paths)
      source = parsed[:source]
      methods = PathManifest.methods(source, path)
      HtmlPaths.grids(source, methods, paths)
    end
    # simplecov:enable

    # Writes one file's page to out, from its sites' operand
    # counts and paths.
    def self.write_page(out, path, parsed,
                        (operands, site_paths), grids)
      source, sites = parsed.values_at(:source, :sites)
      lines = SourceLines.of(source, sites, operands)
      trees = trees(source, sites, lines, site_paths)
      FileUtils.mkdir_p(File.dirname(out))
      File.write(out, HtmlFile.page(path, lines, trees, grids))
    end

    # { first line of a span => [SiteTree.of, ...] } for the
    # sites of one file, each under the span its line is in.
    def self.trees(source, sites, lines, site_paths)
      trees = Hash.new { |all, first| all[first] = [] }
      sites.each do |site, condition|
        first = lines[SourceLines.line_of(site) - 1][:span].begin
        tree = SiteTree.of(source, condition, site_paths.fetch(site))
        trees[first] << located(source, condition, tree)
      end
      trees
    end

    # simplecov:disable
    # SPIKE: tree with an at: of [line, column, line, column]
    # on it and on each of its operands: a leaf's from its byte
    # range, a condition's and an arm's from its extent, the
    # whole of it as written. Columns count characters, not
    # bytes.
    def self.located(source, condition, tree)
      pairs = condition.operands.zip(tree[:operands])
      operands = pairs.map do |operand, node|
        case operand
        when Condition then located(source, operand, node)
        when Arm then located_arm(source, operand, node)
        else node.merge(at: at(source, operand))
        end
      end
      tree.merge(at: at(source, condition.extent), operands:)
    end

    # An arm's node with its at:, nil for an arm with no
    # statements, and its body's tree located.
    def self.located_arm(source, arm, node)
      body = arm.body && located(source, arm.body, node[:body])
      node.merge(at: arm.extent && at(source, arm.extent), body:)
    end

    # [line, column, line, column] of the byte range in source.
    def self.at(source, range)
      [*position(source, range.begin), *position(source, range.end)]
    end

    # [line, column] of a byte offset in source.
    def self.position(source, offset)
      before = source.byteslice(0, offset)
      newline = before.rindex("\n")
      column = before.length - (newline ? newline + 1 : 0)
      [before.count("\n") + 1, column]
    end
    # simplecov:enable
  end
end
