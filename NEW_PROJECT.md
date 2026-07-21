# Starting a new LX8 repo — the checklist

Do these and the recurring problems (billable CI, no runner, licensing gaps) are
solved from commit one. Most of it is one-click or one-command.

## 1. Visibility & licensing (decides your CI cost)
- **Private + proprietary?** → CI runs on the **self-hosted runner** ($0). Follow §3.
- **Open (MIT/GPL) and needs cross-platform CI?** → consider making it **public**.
  Public repos get **free unlimited** GitHub-hosted Actions on Linux/macOS/Windows
  — no runner to manage. (See RUNNERS.md → Exceptions.)

## 2. CI workflow — use the org template, don't hand-roll
- **Actions → New workflow →** pick the **"LX8 · … CI (self-hosted, $0)"** starter
  for your stack (Rust / Node-TS / Go). It's pre-set to `runs-on:
  [self-hosted, macOS]` with concurrency-cancel and macOS-safe steps.
- Never add `runs-on: ubuntu-latest` / `macos-latest` to a **private** repo — it
  bills paid minutes and gets billing-blocked. (RUNNERS.md has the macOS rules.)

## 3. Attach a runner (private repos only)
- **If the org-level runner group covers "All repositories"** → nothing to do; CI
  just runs. (Recommended — set up once, see RUNNERS.md → Option A.)
- **Otherwise**, one command on the runner Mac:
  ```bash
  scripts/bootstrap-runner.sh <this-repo>
  ```
  (Order matters: a `self-hosted` job with no runner queues forever.)

## 4. Branch protection (so the backlog can't rot)
- Require CI green + no direct pushes to the default branch.
- Enable auto-cancel of superseded runs (already in the templates).

## 5. Licensing & provenance hygiene
- Add `LICENSE` (proprietary: `LicenseRef-Lx8-Proprietary`; open: MIT/GPL as chosen).
- Add `REUSE.toml` + per-file SPDX headers; add `CITATION.cff` for published work.
- GPL code (e.g. curupira) stays a **separate process**, never bundled into a
  proprietary binary.

## 6. Release hygiene (if it ships artifacts)
- Gate release/packaging workflows to `on: push: tags: ['v*']` +
  `workflow_dispatch` — never build full releases on every push.
- Cross-platform (Linux/Windows) packaging needs hosted or public runners; keep
  it tag-gated so it bills only at release time.

---
See **RUNNERS.md** for the runner model, macOS-safe workflow rules, and the
exact commands.
