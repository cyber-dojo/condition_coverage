# condition_coverage

Status: an outline of the idea. No working code is published yet.

Condition coverage for Ruby, to run alongside SimpleCov's line and branch
coverage.

## The gap it fills

Ruby's built-in `Coverage` (which SimpleCov reads) tracks branches, not the
conditions inside them:

```ruby
if a || b || c
```

is two branches. Tests that reach both can still leave `b` never true and `c`
never evaluated, and branch coverage reports 100%.

## How it works

At load time, each file under the covered root is parsed with Prism and each
`&&` / `||` operand is wrapped in a recorder call, before compilation:

```ruby
if __cc(7, 0, a) || __cc(7, 1, b) || __cc(7, 2, c)
```

The recorder notes whether the operand was truthy or falsy and returns it
unchanged, so short-circuiting and the value of the expression are preserved.
The rewrite happens in memory only; no file on disk changes.

A static manifest of every site (file, line, column, operand count) is built
by scanning the covered files, so an operand that never ran, or a file never
loaded, is reported as missed rather than silently absent.

## Beyond and/or

The same hook can record decisions hidden inside calls, each with its own
outcome classes:

- `any?` / `all?` / `none?`: empty, decided by the first item, decided later,
  never decided
- `find` / `detect`: found vs nil
- `fetch(k, default)`, `dig`, `Hash#[]` with a default: present vs default
- `x || default` in value context, `&.` safe navigation: nil vs not nil
- ternaries, `unless`, modifier `if`, `case`/`when` and `in` patterns
- regex matches: nil vs MatchData

## Reporting

Gaps only, in the style of a Missing column. Each site shows its source line
with a caret under each operand that was never true, never false, or never
evaluated, plus a JSON form of the same data. An HTML view underlines each
operand in its own colour.

## Intended use

```ruby
# test coverage config, before any application code is required
require 'simplecov'
require 'condition_coverage'
SimpleCov.start do
  # ...
end
ConditionCoverage.start(root: APP_DIR, cover: 'source/**/*.rb')
```

The figure is gathered and reported, not gated.

## Constraints

- CRuby only: the hook is `RubyVM::InstructionSequence.load_iseq`.
- That hook has a single slot, which Bootsnap also uses, so the two cannot
  both be active in one process.
