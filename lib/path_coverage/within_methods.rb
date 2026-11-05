require_relative 'method_statements'

module PathCoverage
  # What is measured within each method of a covered file.
  module WithinMethods
    # Where each statement of the covered file at path, parsed
    # as Manifest.parse gives it, that is no site is reached, as
    # MethodStatements.reaches gives them.
    def self.reaches(path, parsed, config)
      source, sites = parsed.values_at(:source, :sites)
      MethodStatements.reaches(source, config.relative(path), sites)
    end

    # Example: { "k.rb:1:0" => [2, 4], ... }.
    # Each def's card total, [taken, size], in every file in
    # files, { full path => {source:, sites:} }, from paths, as
    # Result#paths gives them, and reached, as Recorder#reached
    # does.
    def self.cards(files, config, paths, reached)
      files.map do |full_path, parsed|
        path = config.relative(full_path)
        source, sites = parsed.values_at(:source, :sites)
        MethodStatements.totals(source, path, paths, reached, sites)
      end.reduce({}, :merge)
    end
  end
end
