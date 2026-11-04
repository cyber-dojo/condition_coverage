require 'json'
require_relative 'kinds'

module PathCoverage
  # The base reporter: the result as raw JSON, which every
  # other reporter can read back.
  module JsonWriter
    # Writes operands, as Result gives them, paths, as
    # PathsReport gives them, and totals, as Kernel.totals gives
    # them, to path as {"sites": {site: [counts, ...]}, "paths":
    # {site: {leaves:, taken:}}, "totals": {"decisions": [taken,
    # possible]}}.
    # parts are json's.
    def self.write(operands, path, paths = {}, **parts)
      File.write(path, json(operands, paths, **parts))
    end

    # The keys of parts listed as { site => [{path:, count:}] }:
    # each path taken that a treatment rules out, as
    # Result#outside gives them.
    LISTED = %i[outside].freeze

    # operands, and any paths, and parts' outside: and totals:,
    # as the JSON report's text, with
    # parts' fingerprint:, as Configuration#fingerprint gives
    # it, the names of the kinds measured, and parts' reached:,
    # as Recorder#reached gives it, even empty, as a run that
    # reached no statement says so; none when not given.
    def self.json(operands, paths = {}, **parts)
      fingerprint = parts.fetch(:fingerprint, {})
      report = { 'sites' => operands, **fingerprint }
      report['paths'] = paths unless paths.empty?
      report.merge!(lists(parts))
      report['reached'] = parts[:reached] if parts.key?(:reached)
      totals = parts.fetch(:totals, {})
      report['totals'] = totals unless totals.empty?
      report['kinds'] = Kinds.names
      JSON.pretty_generate(report)
    end

    # { key => its list } of each of parts' LISTED keys that
    # has one, as listed gives them.
    def self.lists(parts)
      LISTED.filter_map do |key|
        taken = parts.fetch(key, {})
        [key.to_s, listed(taken)] unless taken.empty?
      end.to_h
    end

    # taken, { site => { path => count } }, as JSON lists it,
    # eg { 'k.rb:2:2' => [{ path: [true, false], count: 1 }] }.
    def self.listed(taken)
      taken.transform_values do |counts|
        counts.map { |path, count| { path:, count: } }
      end
    end
  end
end
