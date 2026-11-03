require 'cgi/escape'
require_relative 'condition'

module PathCoverage
  # The tree of a span's sites on a file's page, from SiteTree.of
  # for each site: a grid whose columns are a site's paths.
  module HtmlTree
    OUTCOMES = {
      true => 'T', false => 'F', nil => '',
      ITEMS[0] => '0', ITEMS[1] => '1', ITEMS[2] => '*',
      ANSWERS[0] => 'T', ANSWERS[1] => 'F', ANSWERS[2] => 'TF'
    }.freeze
    # The choices whose arms are named by their kind, eg then,
    # else or when, as their text is statements.
    NAMED_ARMS = [*STATEMENT_CHOICES, 'case'].freeze

    # A bullet marks a path taking an arm.
    TAKEN = { true => [0x2022].pack('U'), false => '' }.freeze

    # The tree of a span, open when its sites have gaps, else
    # hidden: each site's rows in a group of their own.
    def self.of(number, site_trees, open)
      groups = site_trees.map do |site|
        rows = site_rows(site).join
        %(<div class="site" data-site="">#{rows}</div>)
      end
      hidden = open ? '' : ' hidden="hidden"'
      body = groups.join
      %(<div class="tree" id="tree-#{number}"#{hidden}>#{body}</div>)
    end

    # A site's row, naming its operator and each path's count,
    # then the rows of its operands.
    def self.site_rows(site)
      counts = count_cells(site[:counts])
      [row(at(site), operator(site), counts), *operand_rows(site, '')]
    end

    # One cell per path's count, a path never taken marked as a
    # gap.
    def self.count_cells(counts)
      counts.map do |count|
        css = count.zero? ? 'count never' : 'count'
        %(<span class="#{css}" data-count="">#{count}</span>)
      end.join
    end

    # One cell per path, naming each with names.
    def self.cells(values, names = OUTCOMES)
      values.map do |value|
        %(<span class="cell" data-cell="">#{names[value]}</span>)
      end.join
    end

    # SPIKE: the data-at attribute of a node located in its
    # source, '' for one that is not.
    def self.at(node)
      node[:at] ? %( data-at="#{node[:at].join(',')}") : ''
    end

    # The rows of a condition's operands, each branching from
    # its operator after indent; a nested condition's operands,
    # and those of an arm's condition, follow its own row,
    # indented under its branch.
    def self.operand_rows(condition, indent)
      last = condition[:operands].size - 1
      condition[:operands].each_with_index.flat_map do |operand, i|
        tip = i == last
        branch = indent + (tip ? '└─ ' : '├─ ')
        under = indent + (tip ? '   ' : '│  ')
        node_rows(operand, branch, under, condition[:operator])
      end
    end

    # The rows of one operand of a condition whose operator is
    # choice, branching after branch, any operands of its own
    # indented to under.
    def self.node_rows(operand, branch, under, choice)
      if operand.key?(:arm)
        return arm_rows(operand, branch, under, choice)
      end
      return [operand_row(operand, branch)] unless operand[:operator]

      [subtree_row(operand, branch), *operand_rows(operand, under)]
    end

    # An arm's row: a ternary's, ? for then and : for else, an
    # arm holding a condition showing the condition's operator
    # and value, its operands below, a plain arm its text; an
    # if's named then or else, as its text is statements. A
    # plain arm marks the paths taking it.
    def self.arm_rows(arm, branch, under, choice)
      body = arm[:body]
      values = body ? cells(body[:cells]) : cells(arm[:cells], TAKEN)
      text = CGI.escapeHTML(arm_label(arm, choice))
      lead = branch_cell(branch) +
             %(<span class="arm" data-label="">#{text}</span>)
      row = row(%( data-arm=""#{at(arm)}), lead, values)
      body ? [row, *operand_rows(body, under)] : [row]
    end

    # The name of an arm of a condition whose operator is choice.
    def self.arm_label(arm, choice)
      return arm[:arm].to_s if NAMED_ARMS.include?(choice)

      mark = arm[:arm] == :then ? '?' : ':'
      body = arm[:body]
      "#{mark} #{body ? body[:operator] : arm[:text]}"
    end

    # A nested condition's row: its branch, its operator, and
    # its value on each path.
    def self.subtree_row(condition, branch)
      lead = branch_cell(branch) + operator(condition)
      attrs = %( data-subtree=""#{at(condition)})
      row(attrs, lead, cells(condition[:cells]))
    end

    # A row of the grid, with attrs, lead's cells naming it,
    # then values, its cells for each path.
    def self.row(attrs, lead, values)
      %(<div class="row"#{attrs}>#{lead}#{values}</div>)
    end

    # The cell naming a condition's operator.
    def self.operator(condition)
      name = CGI.escapeHTML(condition[:operator])
      %(<span class="operator" data-operator="">#{name}</span>)
    end

    # One operand's row: its branch, text, and its outcome on
    # each path.
    def self.operand_row(operand, branch)
      text = CGI.escapeHTML(operand[:text].to_s)
      lead = branch_cell(branch) +
             %(<span class="text" data-text="">#{text}</span>)
      attrs = %( data-operand=""#{at(operand)})
      row(attrs, lead, cells(operand[:cells]))
    end

    # The cell drawing a row's branch from its operator.
    def self.branch_cell(branch)
      %(<span class="branch" data-branch="">#{branch}</span>)
    end
  end
end
