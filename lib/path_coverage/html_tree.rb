require 'cgi/escape'
require_relative 'condition'
require_relative 'html_labels'
require_relative 'html_syntax'
require_relative 'kinds'

module PathCoverage
  # The tree of a span's sites on a file's page, from SiteTree.of
  # for each site: a grid whose columns are a site's paths.
  module HtmlTree
    OUTCOMES = {
      true => 'T', false => 'F', nil => '',
      ITEMS[0] => '0', ITEMS[1] => '1', ITEMS[2] => '*',
      ANSWERS[0] => 'T', ANSWERS[1] => 'F', ANSWERS[2] => 'TF',
      PRESENCE[0] => [0x25CF].pack('U'),
      PRESENCE[1] => [0x2205].pack('U')
    }.freeze

    # A tick marks a path taking an arm.
    TAKEN = { true => [0x2713].pack('U'), false => '' }.freeze

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

    # One cell per path, naming each with names; a &. receiver's,
    # shown as a glyph, titled not nil or nil for its hover text.
    def self.cells(values, names = OUTCOMES)
      values.map do |value|
        title = PRESENCE.include?(value) ? %( title="#{value}") : ''
        attrs = %(class="cell" data-cell=""#{title})
        %(<span #{attrs}>#{names[value]}</span>)
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
    # indented under its branch. A leaf with sites inside it
    # branches as those sites, then the leaf, in the order they
    # run.
    def self.operand_rows(condition, indent)
      own = Kinds.of(condition[:operator]).rows(condition, indent)
      return own if own

      operands = unfolded(condition[:operands])
      last = operands.size - 1
      operands.each_with_index.flat_map do |operand, i|
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
    # if's named then or else, as its text is statements; its then
    # label marked as a name, as no then is written in its code,
    # where its else is. A plain arm marks the paths taking it.
    def self.arm_rows(arm, branch, under, choice)
      body = arm[:body]
      values = body ? cells(body[:cells]) : cells(arm[:cells], TAKEN)
      named = STATEMENT_CHOICES.include?(choice) && arm[:arm] == :then
      text = HtmlLabels.arm(arm, choice, named)
      flag = named ? ' data-named=""' : ''
      lead = branch_cell(branch) +
             %(<span class="arm" data-label=""#{flag}>#{text}</span>)
      row = row(%( data-arm=""#{at(arm)}), lead, values)
      body ? [row, *operand_rows(body, under)] : [row]
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
      lead = branch_cell(branch) + operator(condition)
      attrs = %( data-subtree=""#{at(condition)})
      row(attrs, lead, cells(condition[:cells]))
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
      label = condition[:label] || condition[:operator]
      name = HtmlSyntax.fragment(label)
      %(<span class="operator" data-operator="">#{name}</span>)
    end

    # One operand's row: its branch, text, coloured as the code it
    # is, and its outcome on each path.
    # An operand that is only called, eg owner at the end of
    # user&.account&.owner, has a tick on each path that called
    # it instead.
    def self.operand_row(operand, branch)
      text = HtmlSyntax.fragment(operand[:text].to_s)
      lead = branch_cell(branch) +
             %(<span class="text" data-text="">#{text}</span>)
      attrs = %( data-operand=""#{at(operand)})
      names = operand[:called] ? TAKEN : OUTCOMES
      row(attrs, lead, cells(operand[:cells], names))
    end

    # The cell drawing a row's branch from its operator.
    def self.branch_cell(branch)
      %(<span class="branch" data-branch="">#{branch}</span>)
    end
  end
end
