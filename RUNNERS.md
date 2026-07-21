# CI runners — the LX8 $0 billing standard

**Rule:** private LX8 repos run CI on **self-hosted macOS runners**, never on
GitHub-hosted `ubuntu-latest`/`macos-latest`. Hosted minutes are billable and
have repeatedly blocked the org's CI ("recent account payments have failed /
spending limit"). Self-hosted runners cost **$0** and are unlimited.

This is not a workaround — it's the standing infrastructure choice (device-lab
plan, Part 6b). The always-on Mac (`LX8-MacBook-Pro-Mark-II`) is the runner host.

## How new projects inherit this automatically

1. **Workflow templates.** Every repo in the org gets LX8 starter workflows in
   **Actions → New workflow** (under "By LX8"): *Rust / Node-TS / Go CI
   (self-hosted, $0)*. They are pre-set to `runs-on: [self-hosted, macOS]` with
   the macOS-safe steps below. Pick the one for your stack — done.
2. **Attach a runner** (see the two options below) so the jobs have somewhere to
   run. Order matters: a `self-hosted` job with no runner **queues forever**.

## Runner options

### Option A — Org-level runner (recommended for "zero per-repo setup")
One runner serves **every** repo, present and future. New repos need *nothing* —
a `runs-on: [self-hosted, macOS]` job just works. One-time, on the runner Mac:

```bash
gh auth refresh -h github.com -s admin:org          # grant the org-runner API
# GitHub → Org Settings → Actions → Runners → New runner → follow the shown
# ./config.sh --url https://github.com/LX8 --token <ORG_TOKEN> --labels self-hosted,macOS,X64
# then: ./svc.sh install && ./svc.sh start
```
Scope the runner group to **All repositories** so future repos are covered with
no extra step. This is the true "solved for every new project" answer.

### Option B — Per-repo runner (isolation; current model)
One runner per repo (mirrors `~/actions-runner-aimem` / `-aimem-os-release`).
More isolation, but each new repo needs one command on the runner Mac:

```bash
scripts/bootstrap-runner.sh <repo>          # mints token, configures, starts svc
```

## macOS-safe workflow rules (baked into the templates)

Self-hosted runners here are **macOS**, so Linux-isms must be avoided:

| Instead of (Linux) | Use (macOS self-hosted) |
|---|---|
| `runs-on: ubuntu-latest` / `macos-latest` | `runs-on: [self-hosted, macOS]` |
| `sudo apt-get install …` | nothing — install via `brew`, or rely on what's present (libpcap ships with macOS; WebKit is WKWebView, no `libwebkit2gtk`) |
| `pip install X` | `python3 -m pip install --user X` (PEP 668 externally-managed) |
| — | always add `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }` |

`actions/setup-go`, `setup-node`, and `dtolnay/rust-toolchain` all work on
self-hosted — they fetch the toolchain per-job, so you don't pre-install Go /
Node / Rust versions on the Mac.

## Exceptions — when self-hosted can't cover it

- **Cross-platform desktop builds** (Tauri/Slint that must produce Linux +
  Windows artifacts) genuinely need hosted Linux/Windows runners. Gate those
  jobs to release tags (`on: push: tags: ['v*']` + `workflow_dispatch`) so they
  bill only when you cut a release, not on every push. Example: `tupan-ide`
  `release.yml`.
- **Open-licensed repos can go public.** Public repos get **free unlimited**
  GitHub-hosted Actions on all OSes — the best fit for MIT/GPL projects that
  need real cross-platform CI (e.g. `tupan-ide`). Prefer this over self-hosting
  a cross-platform project.

## Operational notes

- **Disk:** the runner Mac runs near-full. Each runner + its Rust/Go build cache
  needs headroom; clear regenerable `target/`/`node_modules` build output before
  adding runners.
- **Stale runners:** remove offline runners in *Repo/Org → Settings → Actions →
  Runners* so jobs don't wait on a dead one (e.g. Tupan's old `tupa-ci-mac`).
- **Security:** a self-hosted runner executes whatever a workflow tells it to.
  Keep them on **private** repos only (never public — untrusted-PR RCE risk).
