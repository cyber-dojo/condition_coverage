require 'cgi/escape'

module ConditionCoverage
  # The tree of a span's sites on a file's page, from SiteTree.of
  # for each site.
  module HtmlTree
    HEADINGS = %w[condition true false gap].freeze

    # The tree of a span, open when its sites have gaps, else
    # hidden: a heading row, then each site's rows in a group of
    # their own.
    def self.of(number, site_trees, open)
      groups = site_trees.map do |site|
        rows = site_rows(site).join
        %(<div class="site" data-site="">#{rows}</div>)
      end
      hidden = open ? '' : ' hidden="hidden"'
      body = [heading_row, *groups].join
      %(<div class="tree" id="tree-#{number}"#{hidden}>#{body}</div>)
    end

    # The row naming each column of a tree.
    def self.heading_row
      cells = HEADINGS.map { |name| %(<span>#{name}</span>) }.join
      %(<div class="row headings" data-heading="">#{cells}</div>)
    end

    # A site's operator row, with its own outcome's counts and
    # gap when it has them, then the rows of its operands.
    def self.site_rows(site)
      cells = operator(site)
      cells += count_cells(site) if site.key?(:truthy)
      row = %(<div class="row"#{at(site)}>#{cells}</div>)
      [row, *operand_rows(site, '')]
    end

    # The true and false count and gap cells of a node; a node
    # with no gap says so, as none.
    def self.count_cells(node)
      counts = %i[truthy falsy].map do |name|
        value = CGI.escapeHTML(node[name].to_s)
        %(<span class="#{name}" data-#{name}="">#{value}</span>)
      end
      counts.join + gap_cell(node[:gap])
    end

    # The cell naming a node's gap, or none.
    def self.gap_cell(gap)
      return %(<span class="gap none" data-gap="">none</span>) if gap.nil?

      %(<span class="gap" data-gap="">#{CGI.escapeHTML(gap)}</span>)
    end

    # SPIKE: the data-at attribute of a node located in its
    # source, '' for one that is not.
    def self.at(node)
      node[:at] ? %( data-at="#{node[:at].join(',')}") : ''
    end

    # The rows of a condition's operands, each branching from
    # its operator after indent; a nested condition's operands
    # follow its own row, indented under its branch.
    def self.operand_rows(condition, indent)
      last = condition[:operands].size - 1
      condition[:operands].each_with_index.flat_map do |operand, i|
        tip = i == last
        branch = indent + (tip ? '└─ ' : '├─ ')
        next [operand_row(operand, branch)] unless operand[:operator]

        nested = operand_rows(operand, indent + (tip ? '   ' : '│  '))
        [subtree_row(operand, branch), *nested]
      end
    end

    # A nested condition's row: its branch and its operator.
    def self.subtree_row(condition, branch)
      cells = branch_cell(branch) + operator(condition)
      %(<div class="row" data-subtree=""#{at(condition)}>#{cells}</div>)
    end

    # The cell naming a condition's operator.
    def self.operator(condition)
      name = CGI.escapeHTML(condition[:operator])
      %(<span class="operator" data-operator="">#{name}</span>)
    end

    # One operand's row: its branch, text, true and false
    # counts, and gap.
    def self.operand_row(operand, branch)
      text = CGI.escapeHTML(operand[:text].to_s)
      cells = %(<span class="text" data-text="">#{text}</span>) +
              count_cells(operand)
      lead = branch_cell(branch)
      %(<div class="row" data-operand=""#{at(operand)}>#{lead}#{cells}</div>)
    end

    # The cell drawing a row's branch from its operator.
    def self.branch_cell(branch)
      %(<span class="branch" data-branch="">#{branch}</span>)
    end
  end
end
