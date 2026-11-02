module PathCoverage
  # Names a condition by where it starts in its file, so the
  # rewriter and the manifest agree on which site is which.
  module Site
    # "path:line:column" of node, eg "k.rb:2:2".
    def self.of(path, node)
      loc = node.location
      "#{path}:#{loc.start_line}:#{loc.start_column}"
    end
  end
end
