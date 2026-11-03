require_relative 'configuration'
require_relative 'totals'

module PathCoverage
  # The per-file numbers the HTML index page shows, and their
  # total over every file.
  module Summary
    # One row per file that has sites in site_paths, as
    # Result#paths gives them, in path order: its sites, and
    # its decisions total. Its methods total is nil unless
    # methods, as PathManifest.methods gives them, and paths, as
    # the recorder counts them, are given, as they are when
    # methods are measured.
    def self.files(site_paths, methods = {}, paths = nil)
      by_path = site_paths.group_by { |site, _| path_of(site) }
      by_path.sort.map do |path, sites|
        {
          path:, sites: sites.size,
          decisions: Totals.decisions(sites.to_h),
          methods: paths ? methods_of(path, methods, paths) : nil
        }
      end
    end

    # The methods total of the file at path; [0, 0] for a file
    # with no method of two or more decisions.
    def self.methods_of(path, methods, paths)
      own = methods.select { |site, _| path_of(site) == path }
      Totals.methods(own, paths)
    end

    # The sum of each column over rows, a methods total being
    # nil when the rows' are.
    def self.total(rows)
      methods = rows.map { |row| row[:methods] }
      {
        sites: rows.sum { |row| row[:sites] },
        decisions: add(rows.map { |row| row[:decisions] }),
        methods: methods.first ? add(methods) : nil
      }
    end

    # [name, rows, total] for each of groups, { name => [glob,
    # ...] }, in order: the rows whose path matches any of its
    # globs, and their total. Then Ungrouped, the rows no group
    # matches, when there are any.
    def self.groups(rows, groups)
      grouped = groups.map do |name, globs|
        own = rows.select { |row| matches?(row[:path], globs) }
        [name, own, total(own)]
      end
      every = groups.values.flatten
      rest = rows.reject { |row| matches?(row[:path], every) }
      return grouped if rest.empty?

      grouped << ['Ungrouped', rest, total(rest)]
    end

    # True when path matches any of globs.
    def self.matches?(path, globs)
      globs.any? do |glob|
        File.fnmatch?(glob, path, Configuration::GLOB_FLAGS)
      end
    end

    # [taken, possible] pairs added together, eg [[1, 3], [2, 4]]
    # gives [3, 7]; no pairs, as for a group no file is in, gives
    # [0, 0].
    def self.add(pairs)
      pairs.reduce([0, 0]) do |(taken, possible), (more, of)|
        [taken + more, possible + of]
      end
    end

    # The file a site is in: its name minus :line:column.
    def self.path_of(site)
      site.sub(/:\d+:\d+\z/, '')
    end
  end
end
