# Shell Module (appa-fino) — Improvement TODO
<!-- Living backlog. Completed items removed after commit. -->

---

## 1. MEDIUM — Documentation

### 1.1 README.md missing most functions

**File:** `shared/shell/README.md`

- Not documented: fcd, fkill, flog, fbranch, fhist, fman, frg, fenv, fpath
- Not documented: serve, sizeof, epoch, calc, tmpcd, bak, psgrep, md2pdf, glog
- cp/mv/mkdir alias overrides not mentioned

---

## 2. LOW — Structural Refactoring

### 2.1 `appa-fino-configure.zsh` — extract data from logic

**File:** `zsh-custom.d/appa-fino-configure.zsh` (1132 lines)

- Lines ~350–930 are pure data (parallel arrays for defaults, types, hints, groups)
- Fix: move to `theme/schema.json`; wizard reads schema at runtime

---

## Priority Matrix

| # | Item | File | Impact | Effort |
|---|------|------|--------|--------|
| 1.1 | README missing functions | README.md | LOW | M |
| 2.1 | Split configure data/logic | configure.zsh | LOW | XL |
