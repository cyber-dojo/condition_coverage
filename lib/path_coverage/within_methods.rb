require_relative 'method_statements'

module PathCoverage
  # What is measured within each method of a covered file, when
  # config measures methods: nothing when it does not.
  module WithinMethods
    # Where each statement of the covered file at path that is
    # no site is reached, as MethodStatements.reaches gives them.
    def self.reaches(path, source, config)
      return {} unless config.measures.include?(:methods)

      MethodStatements.reaches(source, config.relative(path))
    end

    # Example: { "k.rb:1:0" => [2, 4], ... }.
    # Each def's card total, [taken, size], in every file in
    # files, { full path => {source:, sites:} }, from paths, as
    # Result#paths gives them, and reached, as Recorder#reached
    # does; nil when config does not measure methods.
    def self.cards(files, config, paths, reached)
      return nil unless config.measures.include?(:methods)

      files.map do |full_path, parsed|
        path = config.relative(full_path)
        MethodStatements.totals(parsed[:source], path, paths, reached)
      end.reduce({}, :merge)
    end
  end
end
