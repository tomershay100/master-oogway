# Shell Module (appa-fino) — Improvement TODO
<!-- Living backlog. Completed items removed after commit. -->

---

## 1. CRITICAL — Bugs That Break Functionality

### 1.2 Arbitrary code execution in `calc`
**File:** `zsh-custom.d/plugins/af-dev/af-dev.plugin.zsh:18`
- User input passed to Python `eval()` with no sandboxing
- Fix: replace with `bc -l <<< "$*"` with a numeric-only input guard

---

## 2. HIGH — Silent Failures & Missing Error Handling

### 2.3 `stty` state not restored on error in `_af_read_key`
**File:** `zsh-custom.d/appa-fino-configure.zsh:543-546`
- Terminal left in raw mode on any interrupt
- Fix: `trap 'stty "$_af_stty" 2>/dev/null' EXIT INT TERM` before the stty call

### 2.5 `port` — no port number validation, unconditional sudo escalation
**File:** `zsh-custom.d/plugins/af-process/af-process.plugin.zsh:25`
- Fix: validate `$1` is 1–65535; only escalate to sudo on EACCES

---

## 3. MEDIUM — Missing Features / Logical Gaps

### 3.6 README.md missing most functions
**File:** `shared/shell/README.md`
- Not documented: fcd, fkill, flog, fbranch, fhist, fman, frg, fenv, fpath
- Not documented: serve, sizeof, epoch, calc, tmpcd, bak, psgrep, md2pdf, glog
- cp/mv/mkdir alias overrides not mentioned

---

## 4. LOW — Structural Refactoring

### 4.2 `appa-fino-configure.zsh` — extract data from logic
**File:** `zsh-custom.d/appa-fino-configure.zsh` (1132 lines)
- Lines ~350–930 are pure data (parallel arrays for defaults, types, hints, groups)
- Fix: move to `theme/schema.json`; wizard reads schema at runtime

---

## Priority Matrix

| # | Item | File | Impact | Effort |
|---|------|------|--------|--------|
| 1.2 | `calc` arbitrary execution | af-dev | HIGH | S |
| 2.3 | `stty` restore on error | configure.zsh | HIGH | S |
| 2.5 | `port` input validation | af-process | MEDIUM | S |
| 3.6 | README missing functions | README.md | LOW | M |
| 4.2 | Split configure data/logic | configure.zsh | LOW | XL |
