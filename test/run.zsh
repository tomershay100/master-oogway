#!/usr/bin/env zsh
setopt EXTENDED_GLOB
MO_ROOT="${0:A:h:h}"
export MO_ROOT
source "$MO_ROOT/test/assert.zsh"

for f in "$MO_ROOT"/test/**/*_test.zsh(N); do
	print -r -- "── ${f#$MO_ROOT/}"
	_T_FILE="$f"
	source "$f"
done

print -r -- ""
print -r -- "passed: $_T_PASS   failed: $_T_FAIL   skipped: $_T_SKIP"
(( _T_FAIL == 0 ))
