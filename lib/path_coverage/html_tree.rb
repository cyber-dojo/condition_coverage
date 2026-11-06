require 'cgi/escape'
require_relative 'condition'
require_relative 'html_branch'
require_relative 'html_cells'
require_relative 'html_labels'
require_relative 'html_syntax'
require_relative 'kinds'

module PathCoverage
  # The tree of a site, from SiteTree.of, as its row's fold in a
  # card shows it: a grid whose columns are the site's paths.
  module HtmlTree
    # A site's row, naming its operator and each path's count,
    # then the rows of its operands.
    def self.site_rows(site)
      counts = HtmlCells.counts(site[:counts])
      [row(at(site), operator(site), counts), *operand_rows(site, '')]
    end

    # SPIKE: the data-at attribute of a node located in its
    # source, '' for one that is not.
    def self.at(node)
      node[:at] ? %( data-at="#{node[:at].join(',')}") : ''
    end

    # The rows of a condition's operands, each branching from
    # its operator after indent; a nested condition's operands,
    # and those of an arm's condition, follow its own row,
    # indented under its branch. A leaf with sites inside it
    # branches as those sites, then the leaf, in the order they
    # run.
    def self.operand_rows(condition, indent)
      own = Kinds.of(condition[:operator]).rows(condition, indent)
      return own if own

      operands = unfolded(shown(condition))
      last = operands.size - 1
      operands.each_with_index.flat_map do |operand, i|
        tip = i == last
        branch = indent + (tip ? HtmlBranch::ELL : HtmlBranch::TEE)
        under = indent + (tip ? HtmlBranch::GAP : HtmlBranch::BAR)
        node_rows(operand, branch, under)
      end
    end

    # The rows of one operand of a condition, branching after
    # branch, any operands of its own indented to under.
    def self.node_rows(operand, branch, under)
      return arm_rows(operand, branch, under) if operand.key?(:arm)
      return [operand_row(operand, branch)] unless operand[:operator]

      [subtree_row(operand, branch), *operand_rows(operand, under)]
    end

    # A ternary's arm's row, ? for then and : for else: an arm
    # holding a condition showing the condition's operator and
    # value, its operands below; a plain arm its text, marking
    # the paths taking it.
    def self.arm_rows(arm, branch, under)
      body = arm[:body]
      values = arm_cells(arm, body)
      label = HtmlLabels.arm(arm)
      lead = HtmlBranch.cell(branch) +
             %(<span class="arm" data-label="">#{label}</span>)
      row = row(%( data-arm=""#{at(arm)}), lead, values)
      body ? [row, *operand_rows(body, under)] : [row]
    end

    # The cells of arm's row: its body's values, when its body is
    # a condition; else a tick on each path that took it.
    def self.arm_cells(arm, body)
      return HtmlCells.of(body[:cells]) if body

      HtmlCells.of(arm[:cells], HtmlCells::TAKEN)
    end

    # The operands of condition a card's fold shows: a ?:'s arms,
    # as its arms are part of its one expression; for any other,
    # eg an if, a ||= or a case, no arm, as which arm a path takes
    # follows from its leaves, but each arm's body, eg a when's
    # patterns, which are leaves of its own.
    def self.shown(condition)
      operands = condition[:operands]
      return operands if condition[:operator] == '?:'

      operands.flat_map do |operand|
        operand.key?(:arm) ? [operand[:body]].compact : [operand]
      end
    end

    # operands with each node standing for the nodes its kind
    # unfolds it into, eg a leaf with sites inside it for those
    # sites, then the leaf; a leaf or an arm for itself.
    def self.unfolded(operands)
      operands.flat_map do |operand|
        operator = operand[:operator]
        operator ? Kinds.of(operator).unfold(operand) : [operand]
      end
    end

    # A nested condition's row: its branch, its operator, and
    # its value on each path.
    def self.subtree_row(condition, branch)
      lead = HtmlBranch.cell(branch) + operator(condition)
      attrs = %( data-subtree=""#{at(condition)})
      row(attrs, lead, HtmlCells.of(condition[:cells]))
    end

    # A row of the grid, with attrs, lead's cells naming it,
    # then values, its cells for each path.
    def self.row(attrs, lead, values)
      %(<div class="row"#{attrs}>#{lead}#{values}</div>)
    end

    # The cell naming a condition's operator, or its label when
    # it has one, eg select { for a site inside a leaf, coloured
    # as the code it is part of.
    def self.operator(condition)
      label = condition.fetch(:label) { condition[:operator] }
      name = HtmlSyntax.fragment(label)
      %(<span class="operator" data-operator="">#{name}</span>)
    end

    # One operand's row: its branch, text, coloured as the code it
    # is, and its outcome on each path.
    def self.operand_row(operand, branch)
      text = HtmlSyntax.fragment(operand[:text].to_s)
      lead = HtmlBranch.cell(branch) +
             %(<span class="text" data-text="">#{text}</span>)
      attrs = %( data-operand=""#{at(operand)})
      row(attrs, lead, HtmlCells.of(operand[:cells]))
    end
  end
end
