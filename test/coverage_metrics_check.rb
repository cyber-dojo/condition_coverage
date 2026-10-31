# Judges a coverage report against min..max bounds.
module CoverageMetricsCheck
  # Returns one line per metric in bounds whose value in report
  # is out of range, eg "code.lines.missed: 2 is outside 0..0";
  # empty when every bound is met.
  def self.breaches(report, bounds, path = [])
    if bound?(bounds)
      breach(report.dig(*path), bounds, path)
    else
      bounds.flat_map do |name, inner|
        breaches(report, inner, path + [name])
      end
    end
  end

  # True for a {min, max} leaf, even one missing a side.
  def self.bound?(node)
    node.key?('min') || node.key?('max')
  end

  # [] when value is within bounds, else its one breach line.
  def self.breach(value, bounds, path)
    problem = bound_problem(bounds) || value_problem(value, bounds)
    problem ? ["#{path.join('.')}: #{problem}"] : []
  end

  # Why a bound naming only one side cannot be applied.
  def self.bound_problem(bounds)
    return 'bound names min but no max' unless bounds.key?('max')

    'bound names max but no min' unless bounds.key?('min')
  end

  # Why value fails its bound, or nil when it is within it.
  def self.value_problem(value, bounds)
    return 'missing from the report' if value.nil?

    range = bounds['min']..bounds['max']
    "#{value} is outside #{range}" unless range.cover?(value)
  end
end
