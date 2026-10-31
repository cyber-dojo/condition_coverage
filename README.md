# condition_coverage

Condition coverage for Ruby, to run alongside SimpleCov's line and branch
coverage.

Status: 0.0.2 covers `&&`, `||`, `and` and `or`: each leaf operand of a
condition, however its operators are chained, nested or grouped. Decisions
hidden inside calls come next (see Roadmap).

Demo: https://cyber-dojo.github.io/condition_coverage/ shows the HTML
report for the mock source tree in `demo/`. `make demo` builds and opens
the same report locally.

## The gap it fills

Ruby's built-in `Coverage` (which SimpleCov reads) tracks branches, not the
conditions inside them:

```ruby
return :ok if ok?(id) && id.start_with?('N')
```

is two branches. Tests that reach both can still leave `id.start_with?('N')`
never false, or never evaluated, and branch coverage reports 100%.

## Use

```ruby
# test coverage config, before any application code is required
require 'simplecov'
require 'condition_coverage'
SimpleCov.start do
  # ...
end
ConditionCoverage.start do
  root APP_DIR                 # cover globs and site names are relative to it
  cover 'source/**/*.rb'       # each matching file is instrumented as it loads
  coverage_dir '/tmp/coverage' # where condition_coverage.json is written
  report :gaps, :html          # the reporters run at exit (default :gaps)
end
```

A misspelt setting or an unknown reporter is refused by name, with the list
of the ones there are. Calling `start` again replaces the configuration.

## What a run reports

As the process exits:

- `condition_coverage.json` is always written to `coverage_dir`: every site
  of every covered file, with each operand's true and false counts. It is
  the base the other reporters read.
- `:gaps` prints one line per missing outcome, in manifest order:

```text
source/kata.rb:3:23 operand 1 never false
source/kata.rb:4:24 never reached
```

A site is named by the `path:line:column` where its condition starts, the
path relative to `root`. A site in a covered file the run never loaded is
still reported, as `never reached`.

A site is an outermost condition. Its operands are numbered left to right
across the whole of it, nested conditions included:

```ruby
ok?(id) && new?(id) && id.size == 6     # one && site, operands 0 1 2
ok?(id) && (new?(id) || id.size == 6)   # an || nested in an && site, 0 1 2
ok?(id) && new?(id) || id.size == 6     # an && nested in an || site, 0 1 2
ids.any? { |k| k && k.ok? } && ok?(id)  # two sites: the block's is its own
```

A chain of one operator is flat; a change of operator, by precedence or by
parentheses, nests. Parentheses are not part of the tree, since they decide
nothing.

- `:html` writes `index.html` to `coverage_dir`: the covered files with
  their sites, outcomes seen (with a percent) and outcomes missing, each
  column sortable. Each file name opens `files/<path>.html`, the file's
  source. On a line holding a condition the line number is a button (blue
  and outlined when every outcome was seen, solid orange when any is
  missing) that opens a tree of the condition: its operators, nested as
  Ruby groups them, and each leaf operand's true and false counts and its
  gap. A condition written over several lines has one button over all of
  its line numbers.

## How it works

At load time each covered file is read and parsed once, with Prism. The
parse gives the manifest: each site's condition tree and the byte range of
each of its leaf operands. The rewriter then inserts a record call around
each leaf, without parsing again, and the result is compiled in place of
the file:

```ruby
ok?(id) && new?(id)
# compiles as
ConditionCoverage.record("k.rb:2:2", 0, (ok?(id))) && ConditionCoverage.record("k.rb:2:2", 1, (new?(id)))
```

Each operand gets parentheses of its own, since one such as `ok? id` (after
`and`) is not valid as a bare argument.

`record` counts whether the operand was truthy or falsy and returns it
unchanged, so short-circuiting and the value of the expression are
preserved. Only text is inserted, never a newline, so backtrace line numbers
still match the file. The rewrite happens in memory; no file on disk
changes. A condition with a single operand is left alone, since branch
coverage already sees both its outcomes.

At exit the manifests parsed during the run are reused; only covered files
the run never loaded are read and parsed then.

## Roadmap

- decisions hidden inside calls, each with its own outcome classes:
  - `any?` / `all?` / `none?`: empty, decided by the first item, decided
    later, never decided
  - `find` / `detect`: found vs nil
  - `fetch(k, default)`, `dig`, `Hash#[]` with a default: present vs default
  - `x || default` in value context, `&.` safe navigation: nil vs not nil
  - ternaries, `unless`, modifier `if`, `case`/`when` and `in` patterns
  - regex matches: nil vs MatchData

## Constraints

- CRuby only: the hook is `RubyVM::InstructionSequence.load_iseq`.
- Ruby 3.2 or later, for `String#bytesplice`.
- That hook has a single slot, which Bootsnap also uses, so the two cannot
  both be active in one process.

## Development

`make all` runs, in a Docker image built from the repo's `Dockerfile`:

- `make lint`: rubocop over `lib/`, `test/` and `bin/` alike
- `make test`: the tests, then a check that the coverage report has zero
  missed lines and branches in both the code and the tests, within the
  bounds in `test/coverage_metrics_params.json`
  (`make test tids='6D1K'` runs only matching tests, and skips the check)
- `make test_check`: shunit2 tests showing that a breached bound fails the
  check with a non-zero exit

`make demo` (not part of `make all`) runs `demo/run.rb` through
`bin/build_demo.sh`, writing the report to `site/` and opening it. The
Pages workflow (`.github/workflows/pages.yml`) runs the same script on
each push to `main` and publishes `site/`.
