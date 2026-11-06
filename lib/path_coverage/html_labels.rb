require_relative 'condition'
require_relative 'html_syntax'
require_relative 'kinds'

module PathCoverage
  # The labels of a site's tree on a file's page, coloured as the
  # code they quote.
  module HtmlLabels
    # The label of an arm of a ternary, the one kind whose fold
    # shows its arms, as Choice names it, as HTML, coloured as
    # HtmlSyntax.ternary_arm has it.
    def self.arm(arm)
      HtmlSyntax.ternary_arm(Kinds::Choice.arm_label(arm))
    end
  end
end
