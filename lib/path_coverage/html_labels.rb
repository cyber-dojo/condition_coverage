require 'cgi/escape'
require_relative 'condition'
require_relative 'html_syntax'
require_relative 'kinds'

module PathCoverage
  # The labels of a site's tree on a file's page, coloured as the
  # code they quote.
  module HtmlLabels
    # The label of an arm of a condition whose operator is
    # choice, as its kind names it, as HTML: a then that names its
    # arm, named, there being no then in the code, plain; a
    # ternary's coloured as HtmlSyntax.ternary_arm has it; any
    # other, eg else or when, coloured as the code it is.
    def self.arm(arm, choice, named)
      label = Kinds.of(choice).arm_label(arm, choice)
      return CGI.escapeHTML(label) if named
      return HtmlSyntax.ternary_arm(label) if choice == '?:'

      HtmlSyntax.fragment(label)
    end

    # [class, mark] of a path's count cell, by whether its count
    # is zero.
    MARKS = { true => ['count never', '0'],
              false => ['count', '*'] }.freeze

    # Example: 1 gives 1 time, 1284 gives 1,284 times.
    # How many times a path was taken, as its mark's hover chip
    # reads it, its thousands apart, so a big count still reads.
    def self.times(count)
      digits = count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
      "#{digits} #{count == 1 ? 'time' : 'times'}"
    end
  end
end
