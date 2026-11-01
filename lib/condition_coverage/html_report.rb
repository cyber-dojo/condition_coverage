require 'fileutils'
require_relative 'html_file'
require_relative 'html_index'
require_relative 'site_tree'
require_relative 'source_lines'
require_relative 'summary'

module ConditionCoverage
  # The :html reporter: index.html, and files/<path>.html for
  # each covered file, written to the configuration's
  # output_dir.
  module HtmlReport
    # Writes every page. operands are as Result#operands gives
    # them; files is { full path => {source:, sites:} } for each
    # covered file, as the kernel parsed it.
    def self.write(operands, files, config)
      dir = config.output_dir
      index = HtmlIndex.page(Summary.files(operands))
      File.write("#{dir}/index.html", index)
      files.each do |full_path, parsed|
        path = config.relative(full_path)
        out = "#{dir}/files/#{path}.html"
        write_page(out, path, parsed, operands)
      end
    end

    # Writes one file's page to out.
    def self.write_page(out, path, parsed, operands)
      source = parsed[:source]
      lines = SourceLines.of(source, parsed[:sites], operands)
      trees = trees(source, parsed[:sites], lines, operands)
      FileUtils.mkdir_p(File.dirname(out))
      File.write(out, HtmlFile.page(path, lines, trees))
    end

    # { first line of a span => [SiteTree.of, ...] } for the
    # sites of one file, each under the span its line is in.
    def self.trees(source, sites, lines, operands)
      trees = Hash.new { |all, first| all[first] = [] }
      sites.each do |site, condition|
        first = lines[SourceLines.line_of(site) - 1][:span].begin
        tree = SiteTree.of(source, condition, operands.fetch(site))
        trees[first] << tree
      end
      trees
    end
  end
end
