# path_coverage

[![Gem Version](https://img.shields.io/gem/v/path_coverage)](https://rubygems.org/gems/path_coverage)
[![Downloads](https://img.shields.io/gem/dt/path_coverage)](https://rubygems.org/gems/path_coverage)
[![License](https://img.shields.io/github/license/cyber-dojo/path_coverage)](LICENSE.md)

Path coverage for Ruby, to run alongside SimpleCov's line and branch
coverage.

Gem: https://rubygems.org/gems/path_coverage (which shows the latest
version).

Status: sites cover `&&`, `||`, `and`, `or`, the ternary `?:`,
`if`/`elsif`/`else` and `unless` (modifiers included), `case`/`when`
with a subject, and the block methods `any?` `all?` `none?` `find`
`detect` `find_index` `take_while` `select` `filter` `reject`
`partition` `count` `filter_map`. Method paths cover `if` decisions.
More decisions hidden inside calls come next (see Roadmap).

Demo: https://cyber-dojo.github.io/path_coverage/ shows the HTML report
for the mock source tree in `demo/`. `make demo` builds and opens the
same report locally.

Take this method:

```ruby
def fee(user, order)
  total = 100
  if user.member? && order.paid?
    total -= 5
  end
  if order.big?
    total -= 10
  end
  total
end
```

Tests that run both `if`s both ways reach every line and every branch,
so SimpleCov, which reads Ruby's built-in `Coverage`, reports 100%. Yet
they can still miss paths, at two scopes, and path_coverage lists each
path no test took.

## Within each decision

The first `if` can go three ways: member and paid, member and not
paid, not a member. A member who has not paid may never have been
tried.

![The first if's grid: a column per way it can go, each headed by
its count, the member who has not paid at 0](docs/decision.png)

## Within each method

The two `if`s can go four ways together. A paying member with a small
order may never have been tried.

![fee's grid: a column per way its two ifs can go together, each
headed by its count, true then false at 0 and selected](docs/method.png)

## Use

```ruby
# test coverage config, before any application code is required
require 'simplecov'
require 'path_coverage'
SimpleCov.start do
  # ...
end
PathCoverage.start do
  root APP_DIR                 # cover globs and site names are relative to it
  cover 'source/**/*.rb'       # each matching file is instrumented as it loads
  skip 'source/vendor/**/*.rb' # except these, though a cover glob matches them
  coverage_dir '/tmp/coverage' # where path_coverage.json is written
  measure :decisions, :methods # :decisions alone unless :methods is named
  report :gaps, :html          # the reporters run at exit (default :gaps);
                               # also :summary and :post
  group 'Models', 'source/models/**/*.rb'   # a tab of its own on index.html
end
```

A misspelt setting or an unknown reporter is refused by name, with the list
of the ones there are. Calling `start` again replaces the configuration.
`cover` and `skip` can each be given more than once; a file matching any
`skip` glob is neither instrumented nor reported. Each `group`, given a name
and one or more globs, gets a tab of its own on the HTML index, after All
files, with its own Total row; covered files no group matches get an
Ungrouped tab. A file may be in more than one group.

## When you cannot change the code!

A run whose code cannot be changed, such as a script in a `docker build`
step, can be covered from its environment alone:

```sh
RUBYOPT=-rpath_coverage/auto
PATH_COVERAGE_ROOT=/app                   # root
PATH_COVERAGE_COVER=src/**/*.rb,lib/*.rb  # cover, comma-separated
PATH_COVERAGE_SKIP=src/vendor/**/*.rb     # skip, comma-separated, optional
PATH_COVERAGE_DIR=/tmp/paths              # coverage_dir
PATH_COVERAGE_COLLECTOR=http://host.docker.internal:4570/runs
```

This starts with `report :post`. With no `PATH_COVERAGE_COLLECTOR` it
starts nothing and prints nothing, so an image can set `RUBYOPT` for every
run and measure only those given a collector.

The gem's `path_coverage_collector` command is that collector. It saves
each report POSTed to it as a numbered file, and once every run is done
they render as one report:

```sh
path_coverage_collector 4570 /tmp/paths/runs   # until sent TERM
```

- A report is saved before it is answered 200, so a 200 means it is on
  disk. A report cut short, eg by a sender dying mid-send, is answered
  400 and not saved. One that cannot be saved is answered 500.
- `GET /alive` answers 200 while the collector runs.
- `GET /ready` answers 200 when its dir is writable, 503 when not. Wait
  for it before starting the runs.
- On TERM it stops accepting connections, finishes the report in hand,
  and exits 0.

```ruby
runs = Dir['/tmp/paths/runs/*.json']
PathCoverage::Render.from_json(config, runs)
```

## What a run reports

As the process exits:

- `path_coverage.json` is always written to `coverage_dir`: every site
  of every covered file, with each operand's true and false counts under
  `sites`, each site's paths under `paths`, each method's paths taken
  under `method_paths` when `:methods` is measured, and the paths taken
  of all possible under `totals`, as [taken, possible]: `decisions`,
  `methods` when `:methods` is measured, and, with groups, each group's
  own under `groups`, eg `"groups": {"code": {"decisions": [481, 567]}}`.
  It is the base the other reporters read, so they can also be run
  later, in another process, from
  it alone: `PathCoverage::Render.from_json(config)`, where `config` is a
  `PathCoverage::Configuration` built from the same settings block.
  Given several runs' reports, `Render.from_json(config, paths)` adds
  their counts together first, so the report shows only the gaps that
  every run left.
- `:gaps` prints one line per path never taken, in manifest order: a
  site's naming the outcome of each leaf on it, a method's the outcome
  of each decision on it, by line:

```text
source/kata.rb:3:23 path never taken: `ok?(id)` true, `new?(id)` false
source/kata.rb:4:24 never reached
source/fee.rb:2:2 fee path never taken: line 4 true, line 7 false
```

### Decisions

The paths within each decision are always measured, whatever `measure`
names.

A site is named by the `path:line:column` where it starts, the path
relative to `root`. A site in a covered file the run never loaded is
still reported, as `never reached`.

A path is the outcome of each leaf one evaluation of the site reached, in
order; a leaf that short-circuiting skipped is not on it. Each leaf is
quoted as a Markdown code span, on one line, its fence one backtick longer
than any run of backticks inside it. The gap lines are for people; a tool
should read the JSON, whose `paths` give each site's leaves as
`line:column` spans, and each possible path with its count:

```json
"paths": {
  "source/kata.rb:3:23": {
    "leaves": [["3:23", "3:30"], ["3:34", "3:42"]],
    "taken": [
      { "path": [true, true], "count": 2 },
      { "path": [true, false], "count": 0 },
      { "path": [false, null], "count": 1 }
    ]
  }
}
```

A site is an outermost condition. Its leaves are numbered left to right
across the whole of it, nested conditions included. Each example below is
a line of code, then its site's tree, as a popout draws it:

```text
ok?(id) && (new?(id) || id.size == 6)

&&                            one site
├─ ok?(id)                    leaf 0
└─ ||                         nested by parentheses, no site of its own
   ├─ new?(id)                leaf 1
   └─ id.size == 6            leaf 2
```

```text
ids.map { |k| k && k.ok? } && ok?(id)

&&                            one site
├─ ids.map { ... }            leaf 0
└─ ok?(id)                    leaf 1

&&                            a second site, inside the block
├─ k                          leaf 0
└─ k.ok?                      leaf 1
```

```text
ok?(id) ? new?(id) && id.size == 6 : :no

?:                            one site
├─ ok?(id)                    leaf 0
├─ ? &&                       an arm holding a condition, part of the site
│  ├─ new?(id)                leaf 1
│  └─ id.size == 6            leaf 2
└─ : :no                      a plain arm
```

A ternary is a site even when its predicate is a single leaf. An arm
holding a condition of `&&`, `||`, `and`, `or` or `?:` is part of the
ternary's site, its leaves numbered after the predicate's, so the site's
paths run through whichever arm the predicate picks. Any other arm, like a
block, is not part of it, though a condition inside it is a site of its
own.

An `if` or an `unless`, a modifier included, is a site too, even when
its predicate is a single leaf: its predicate nests in it, an `&&` there
being no site of its own, and its `then` and `else` arms are plain, as
they are statements; an `unless` takes its `then` arm when its predicate
is false. It is named at its keyword, and its extent is its keyword to
the end of its predicate, so a site inside an arm keeps its own button.
An `elsif` is a site of its own.

A `case` with a subject is a site whose leaves are its `when` patterns,
tried in order until one matches. Each pattern is wrapped in a stand-in
whose `===` calls the pattern's `===` once, exactly as the `case` would,
and notes whether it matched. A `case` with no subject, or with a splat
among its patterns, is no site.

A call to a block method, with no arguments and a block of one
expression, is a site named at its method. Its two leaves are its
receiver, showing how many items its block was called with (`0 items`,
`1 item` or `2+ items`), and its block's expression: for `any?` `all?`
`none?` `find` `detect` `find_index` and `take_while`, which stop once
their block decides, its last answer; for `select` `filter` `reject`
`partition` `count` and `filter_map`, which call it with every item,
whether its answers were `all true`, `all false` or `both`. Both are
noted from the block's own calls, so the receiver is never asked for its
size, which could consume a sequence that can be read only once.

A `||=` or `&&=` write is a site, whatever its target: a variable of any
kind, a constant, an attribute (`self.size ||= n`) or an index
(`store[key] ||= key.upcase`). Its one leaf is its target, and its right
side is an arm, run when the target is false for `||=`, true for `&&=`,
as an `unless` or an `if` runs its arm. The target is never read again,
since reading `store[key]` could call a method twice: its outcome follows
from whether the right side ran. So `@clock ||= Clock.now` called only
once, as a fresh object, leaves the path with `@clock` true a gap.

A chain of one operator is flat; a change of operator, by precedence or by
parentheses, nests. Parentheses are not part of the tree, since they decide
nothing.

A leaf whose form allows one outcome only needs only to be evaluated: a
path needing its other outcome is impossible, not a gap. `Foo.new`,
literals (`'s'`, `1`, `:k`, `[]`, `{}`, `true`) and lambdas can only be
truthy, as can `$stdout` and `$stderr`, which Ruby refuses to set to nil
or false. Other globals, `$stdin` among them, can be either, as can
constants, since one can hold nil or false (`VERBOSE = false`). `nil` and
`false` can only be falsy:

```ruby
@clock = options[:clock] || MonotonicClock.new  # leaf 1: never evaluated, or no gap
```

Any other leaf, a call among them, is taken to have either outcome, as its
form alone cannot say which it returns. So a call that never returns nil
or false still leaves a path needing it falsy, which no test can take:

```ruby
methods: paths && methods_of(path, methods, paths)  # [true, false] impossible
methods: paths ? methods_of(path, methods, paths) : nil  # the same, no such path
```

Written as a choice, the same code has no such path. Reporting a gap that
cannot be closed is the lesser error than hiding one that can.

### Methods

With `measure :decisions, :methods`, each method with two or more
decisions also counts each call's path through them: the outcome of each
decision it reached, in order. A method is named by the `path:line:column`
of its `def`, then its name. Each decision is one outcome on the path,
however many leaves its predicate has; those are its site's to show. So a
site's columns stay its own leaves' combinations, and a method's its own
decisions', rather than multiplying together. A decision whose arm always
leaves the method ends the path there.

The JSON report's `method_paths` lists each method's paths taken, with
their counts, so a later render, or several runs' reports merged, still
shows them. A report with none, eg from a run that did not measure
`:methods`, renders as no method path taken:

```json
"method_paths": {
  "source/fee.rb:2:2": [
    { "path": [true, false], "count": 1 }
  ]
}
```

### Reporters

- `:html` writes `index.html` to `coverage_dir`: the covered files with
  their sites and their paths taken of all possible, within each decision
  and, when `:methods` is measured, within each method (eg
  `9 / 28 (32%)`, or `-` for a file with no method of two or more
  decisions), each column sortable, and a Total row for every file
  together. Each file name opens `files/<path>.html`, the file's
  source. On a line holding a site the line number is a button (blue
  and outlined when every outcome was seen, solid orange when any is
  missing) that opens a grid of the site's paths, on the left. Its rows
  are the site's tree: its operators, nested as Ruby groups them, a
  ternary's arms marked `?` and `:`, an `if`'s named `then` and `else`,
  and its leaves. Its columns are the site's paths, never taken first,
  each headed by its count, orange when zero; a leaf shows its outcome on
  each path, T or F, blank where the path never reached it, and a plain
  arm a dot on each path that took it. A site written over several lines
  has one button over all of its line numbers. Grids with gaps start
  open. A header that stays at the top of the page lists every site as a
  link to its line, covered sites first, then those with gaps, and arrows
  beside each site with gaps jump to the previous and next one, wrapping
  round at either end. Measuring paths, each method's grid of its
  decisions' paths opens on the right.
- `:post` sends the JSON report, as an HTTP POST, to the url set by
  `collector 'http://...'`. It is for a run whose own files are thrown
  away, such as a failing `docker build` step. It prints nothing, never
  goes through an `http_proxy`, and gives up in silence on a collector
  that cannot be reached or does not answer within a second, so the
  run's output and exit status are unchanged.
- `:summary` prints each total as SimpleCov prints its line and branch
  coverage, the methods line only when `:methods` is measured:

```text
Path coverage within decisions: 527 / 631 (83.52%)
Path coverage within methods: 44 / 52 (84.62%)
```

  With groups, each group is a heading, its own totals indented under it,
  and there is no total over every group; a total with no path possible
  shows `-` for its percent:

```text
code:
  Path coverage within decisions: 481 / 567 (84.83%)
  Path coverage within methods: 41 / 49 (83.67%)
test:
  Path coverage within decisions: 65 / 84 (77.38%)
  Path coverage within methods: 3 / 3 (100.00%)
```

## How it works

At load time each covered file is read and parsed once, with Prism. The
parse gives the manifest: each site's condition tree and the byte range of
each of its leaves. The rewriter then inserts a record call around each
leaf, and a leave call around the whole site, whose first argument enters
it, without parsing again, and the result is compiled in place of the
file:

```ruby
ok?(id) && new?(id)
# compiles as
PathCoverage.leave(PathCoverage.enter("k.rb:2:2", 2), PathCoverage.record("k.rb:2:2", 0, ok?(id)) && PathCoverage.record("k.rb:2:2", 1, new?(id)))
```

An `if` site's leave call wraps its predicate alone, as its path is
decided there, so an arm that returns or raises still counts it.
Measuring paths, each method starts a path at its entry, and each
decision's predicate is wrapped in a decide call too, outside its site's
calls.

A command call such as `ok? id` (after `and`) is not valid as a bare
argument, so that leaf alone gets parentheses of its own, and so does a
whole `and` or `or` inside its leave call. Nothing else does:
parentheses make a statement, and a statement on a continuation line gives
that line a line-coverage count of its own, which changes SimpleCov's line
totals. So a command call, or an `and` or `or`, written over several lines
can add to SimpleCov's relevant lines; nothing else does.

`record` counts whether its value was truthy or falsy, and notes it on the
site's current path; `enter` starts that path, and `leave` counts it.
Each returns its value unchanged, so short-circuiting and the value of
the expression are preserved. Paths are kept per fiber, so threads never
mix their outcomes; an evaluation cut short by a raise counts no path,
so no path is ever claimed that was not taken. Only text is inserted,
never a newline, so backtrace line numbers still match the file. The
rewrite happens in memory; no file on disk changes.

At exit the manifests parsed during the run are reused; only covered files
the run never loaded are read and parsed then.

## Roadmap

- decisions hidden inside calls, each with its own outcome classes:
  - `one?`, whose last answer does not decide it, and block methods
    with blocks of more than one expression
  - `fetch(k, default)`, `dig`, `Hash#[]` with a default: present vs default
  - `x || default` in value context, `&.` safe navigation: nil vs not nil
  - `x rescue y` modifier: raised vs not raised
  - `case` with no subject, and `case`/`in` patterns
  - regex matches: nil vs MatchData
- a method that never returns nil or false, declared once at its
  definition, eg `# path_coverage: returns an Array` above
  `def self.methods_of`, so each call to it counts as a leaf that is only
  truthy, as `Foo.new` is. A run where it returns nil or false reports
  the declaration as wrong, and the report lists the methods so declared.
  Later, a method's non-nil return type could come from the project's RBS
  signatures (`sig/*.rbs`) instead.
- exceptions the code itself names: a `begin` or `def` with `rescue`
  clauses as a site, like a `case`, whose paths are no raise and each
  clause that rescued, eg `rescue IOError` never taken. Branch coverage
  ignores `rescue`, and tests reach these paths with real input. A raise
  that nothing names, from any call, stays out, as every leaf would gain
  a third outcome that only fault injection could take.
- an evaluation that raised part way through a site, eg
  `ok?(id) && fetch(id)` where `fetch` raises, reported as a path that
  raised rather than dropped as unfinished.
- complexity maximums, reported and gated, since the possible paths
  count how much there is to test, not only how much was tested. A
  file's total measures its size, so each is a maximum over smaller
  parts:
  - paths in one decision, eg 6 for a `select` block
  - paths through one method's decisions, eg 2 top-level ifs give 4
  - paths within each decision, summed over every decision in one
    method, nested ones included, eg decisions of 2, 3 and 15 paths
    sum to 20. Every method has one, and it grows as the method gains
    conditions, where the paths through a method multiply.

## Constraints

- CRuby only: the hook is `RubyVM::InstructionSequence.load_iseq`.
- Ruby 3.2 or later, for `String#bytesplice`.
- That hook has a single slot, which Bootsnap also uses, so the two cannot
  both be active in one process.

## Development

`make all` runs, in a Docker image built from the repo's `Dockerfile`:

- `make lint`: rubocop over `lib/`, `test/` and `bin/` alike
- `make test`: the tests, with path_coverage measuring its own `lib/` and
  `test/`, then a check that SimpleCov's report has zero missed lines and
  branches in both the code and the tests, and that every path within the
  tests' methods was taken, within the bounds in
  `test/coverage_metrics_params.json` (a path bound is eg
  `test.paths.methods.missed`, and a missing path report denies it)
  (`make test tids='6D1K'` runs only matching tests, and skips the check)
- `make test_check`: shunit2 tests showing that a breached bound fails the
  check with a non-zero exit

Each run prints its seed; `SEED=n make test` replays that run's order of
files and tests. When the coverage check fails, it names each line and
branch missed.

A run ends with each group, code and test, as a heading over its four
figures, SimpleCov's and path_coverage's together, then where each report
is, each with a code and a test tab, then the check's verdict:

```text
code:
  Line coverage: 1270 / 1270 (100.00%)
  Branch coverage: 321 / 321 (100.00%)
  Path coverage within decisions: 481 / 567 (84.83%)
  Path coverage within methods: 41 / 49 (83.67%)
test:
  Line coverage: 2250 / 2250 (100.00%)
  Branch coverage: 43 / 43 (100.00%)
  Path coverage within decisions: 65 / 84 (77.38%)
  Path coverage within methods: 3 / 3 (100.00%)
Coverage report: .../reports/index.html
Path coverage report: .../reports/paths/index.html
coverage: ALLOWED
```

`bin/check_coverage_metrics.rb` prints the groups, reading SimpleCov's
figures from `reports/coverage_metrics.json` and path_coverage's from the
`totals` in `reports/paths/path_coverage.json`; SimpleCov's own console
lines, totals over every group, are silenced. The tool measuring paths is
a copy of `lib/` renamed `PathCoverageSelf` (`test/self_coverage.rb`), so
the tests start and restart `PathCoverage` as always. SimpleCov's figures
for `lib/` are the same with it as without.

`make demo` (not part of `make all`) runs `demo/run.rb` through
`bin/build_demo.sh`, writing the report to `site/` and opening it. The
Pages workflow (`.github/workflows/pages.yml`) runs the same script on
each push to `main` and publishes `site/`.

`bin/capture_readme_images.sh` rebuilds the demo and saves this README's
two screenshots, `docs/decision.png` and `docs/method.png`, from it with
headless Chrome. Run it again whenever the report's look changes.
