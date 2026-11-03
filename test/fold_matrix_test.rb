require_relative 'test_helper'
require 'path_coverage/kernel'
require 'path_coverage/manifest'
require 'path_coverage/site_paths'
require 'tmpdir'

class FoldMatrixTest < Id58TestBase
  # Its test swaps the configuration of the one global load
  # hook.
  serial!

  # Each kind of site, as an expression over a, b, ids and u.
  KINDS = {
    '&&' => 'a && b',
    '||' => 'a || b',
    '?:' => '(a ? b : nil)',
    'case' => '(case a when 1 then b end)',
    'any?' => 'ids.any? { |i| i.odd? }',
    'all?' => 'ids.all? { |i| i.odd? }',
    'none?' => 'ids.none? { |i| i.odd? }',
    'find_index' => 'ids.find_index { |i| i.odd? }',
    'take_while' => 'ids.take_while { |i| i.odd? }',
    'find' => 'ids.find { |i| i.odd? }',
    'select' => 'ids.select { |i| i.odd? }',
    '&.' => 'u&.name',
    '||=' => '(@m ||= a)'
  }.freeze

  # Each place one expression can sit in another, X marking it.
  POSITIONS = {
    'operand' => '(X) && c',
    'predicate' => '(X) ? 1 : 2',
    'if' => "if X\n    1\n  else\n    2\n  end",
    'receiver' => '(X).to_s.empty? && c',
    'argument' => 'c.equal?(X) && c',
    'arm' => 'c ? (X) : 2'
  }.freeze

  # Every input each method is called with.
  VALUES = [nil, true, 1].freeze
  IDS = [[], [1], [2], [1, 2]].freeze

  test 'Fm7k01', %w(
  | Example: a && b as the operand of (X) && c, and every other
  | kind of site in every other position
  | One expression is one site, whatever sites nest in it and
  | wherever they sit.
  | The rewritten code returns what the uninstrumented code does.
  | Every path recorded is one of the site's possible paths.
  ) do
    dir = Dir.mktmpdir('Fm7k01')
    named = Struct.new(:name)
    users = [nil, named.new('kim')]
    cases = KINDS.flat_map do |kind, expression|
      POSITIONS.map do |position, outer|
        [kind, position, outer.sub('X', expression)]
      end
    end
    cases.each_with_index do |(_, _, body), index|
      File.write("#{dir}/m#{index}.rb", source("Fm7k#{index}", body))
    end
    on_exit = ->(&_report) {} # this test reads the recorder
    PathCoverage.start(on_exit:) do
      root dir
      cover '*.rb'
      coverage_dir dir
    end
    inputs = VALUES.product(VALUES, VALUES, IDS, users)
    actual = cases.each_with_index.map do |(kind, position, body), i|
      file = "m#{i}.rb"
      require "#{dir}/#{file}"
      plain = source("Plain#{i}", body)
      eval(plain, TOPLEVEL_BINDING) # rubocop:disable Security/Eval
      same = inputs.map { call("Fm7k#{i}", _1) } ==
             inputs.map { call("Plain#{i}", _1) }
      mine = source("Fm7k#{i}", body)
      sites = PathCoverage::Manifest.sites(mine, file)
      impossible = sites.flat_map do |site, condition|
        PathCoverage.recorder.site_paths[site].keys -
          PathCoverage::SitePaths.possible(condition)
      end
      ["#{kind} as #{position}", sites.size, same, impossible]
    end
    expected = cases.map do |kind, position, _|
      ["#{kind} as #{position}", 1, true, []]
    end
    assert_equal expected, actual
  end

  test 'Fm7k02', %w(
  | Example: a && b as the operand of (X) && c, with && ignored,
  | and every other kind of site in every other position, with
  | that kind ignored
  | No site measures the ignored operator, at its top or
  | nested in it.
  | The rewritten code returns what the uninstrumented code does.
  | Every path recorded is one of the site's possible paths.
  ) do
    dir = Dir.mktmpdir('Fm7k02')
    named = Struct.new(:name)
    users = [nil, named.new('kim')]
    cases = KINDS.flat_map do |kind, expression|
      POSITIONS.map do |position, outer|
        [kind, position, outer.sub('X', expression)]
      end
    end
    inputs = VALUES.product(VALUES, VALUES, IDS, users)
    actual = cases.each_with_index.map do |(kind, position, body), i|
      name = "Fm7kIg#{i}"
      file = "ig#{i}.rb"
      File.write("#{dir}/#{file}", source(name, body))
      on_exit = ->(&_report) {} # this test reads the recorder
      PathCoverage.start(on_exit:) do
        root dir
        cover file
        coverage_dir dir
        ignore kind
      end
      require "#{dir}/#{file}"
      plain = source("PlainIg#{i}", body)
      eval(plain, TOPLEVEL_BINDING) # rubocop:disable Security/Eval
      same = inputs.map { call(name, _1) } ==
             inputs.map { call("PlainIg#{i}", _1) }
      sites = PathCoverage::Manifest.sites(source(name, body), file,
                                           [kind])
      # a Condition's inspect shows its own and every nested one's
      shown = sites.values.inspect
      named = shown.include?("operator=#{kind.inspect}")
      impossible = sites.flat_map do |site, condition|
        PathCoverage.recorder.site_paths[site].keys -
          PathCoverage::SitePaths.possible(condition)
      end
      ["#{kind} as #{position}", named, same, impossible]
    end
    expected = cases.map do |kind, position, _|
      ["#{kind} as #{position}", false, true, []]
    end
    assert_equal expected, actual
  end

  private

  # A module named name, its one method m's body body, on line 3.
  def source(name, body)
    "module #{name}\n  def self.m(a, b, c, ids, u)\n  " \
      "#{body}\n  end\nend\n"
  end

  # The result of the module named name's m called with args.
  def call(name, args)
    Object.const_get(name).m(*args)
  end
end
