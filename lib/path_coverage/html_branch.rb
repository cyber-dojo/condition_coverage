module PathCoverage
  # The branches of a site's tree on a file's page, joining each
  # operand's row to its operator's. A branch is a string of
  # kinds, one letter per cell: t a tee, l an ell, v a bar, h a
  # dash, s a space. CSS draws each kind as lines a whole row
  # tall, so a branch joins the rows above and below it.
  module HtmlBranch
    # The branch to an operand with more after it.
    TEE = 'ths'.freeze
    # The branch to the last operand.
    ELL = 'lhs'.freeze
    # The indent under an operand with more after it, its bar
    # running on down to them.
    BAR = 'vss'.freeze
    # The indent under the last operand.
    GAP = 'sss'.freeze

    # Example: ths gives a tee, a dash and a space cell.
    # The cell drawing branch: a cell of each of its kinds,
    # hidden from screen readers, as the rows' order already
    # says how they nest.
    def self.cell(branch)
      cells = branch.chars.map do |kind|
        %(<span class="bx" data-bx="#{kind}"></span>)
      end
      attrs = 'class="branch" data-branch="" aria-hidden="true"'
      %(<span #{attrs}>#{cells.join}</span>)
    end
  end
end
