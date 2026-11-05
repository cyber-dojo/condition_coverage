module PathCoverage
  # One card of a file's page, as the page lays out the code
  # around it: its first and last lines, its def's column, its
  # status, gaps or covered, whether it is a top card, of sites
  # outside every def, how many sites a top card holds, its
  # button showing that count, nil for a method's, and its HTML.
  Card = Data.define(:first, :last, :column, :status, :top, :sites,
                     :html) do
    # True when line is one of the card's lines.
    def holds?(line)
      (first..last).cover?(line)
    end
  end
end
