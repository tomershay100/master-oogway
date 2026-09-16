# test

A small zsh assertion harness. No dependencies beyond zsh itself.

```bash
zsh test/run.zsh            # every test/**/*_test.zsh
zsh test/lint_platform.zsh  # the platform invariant
```

`run.zsh` sources each test file in turn, prints one line per assertion, and
exits non-zero if any failed.

## Writing a test

Test files are named `*_test.zsh` and are sourced with `$MO_ROOT` set to the
repo root and the assertions already loaded:

```zsh
assert_eq       "$expected" "$actual"    "label"
assert_contains "$haystack" "$needle"    "label"
assert_match    "$string"   "$regex"     "label"
assert_ok       "label" some command...
assert_fail     "label" some command...
assert_true     "label" "$x > 0"
assert_not_contains "$haystack" "$needle" "label"
```

Plugins are sourced in a clean subshell rather than into the test shell, so one
plugin's aliases cannot leak into another's assertions.

## The platform lint

`lint_platform.zsh` fails if anything under `plugins/` or `themes/` calls
`uname`, reads `/proc`, or uses a GNU-only flag. Those belong in
`omz-custom/lib/platform.zsh`, which is the one file the lint exempts.

This is what stops the abstraction eroding one `[[ $(uname) == Darwin ]]` at a
time.

Until every plugin has been routed through `lib/platform.zsh`, the lint doubles
as the remaining worklist: each line it prints is a call site still to move.
It goes clean once the routing is complete, and is enforcing from then on.

## A note on tests that touch the terminal

Anything reaching `fzf` must be given a non-interactive path — a `PATH` without
`fzf` on it, or `--filter=`. A test that opens a picker blocks the whole suite
with no output, which is a slow thing to diagnose.
