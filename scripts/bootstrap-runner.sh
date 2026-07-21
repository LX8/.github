#!/usr/bin/env bash
# bootstrap-runner.sh — attach a $0 self-hosted GitHub Actions runner to ONE LX8
# repo, so its CI stops consuming billable GitHub-hosted minutes.
#
#   ./bootstrap-runner.sh <repo> [org]        # org defaults to LX8
#   ./bootstrap-runner.sh my-new-service
#
# This is the per-repo runner model (matches ~/actions-runner-aimem-os-release).
# For a zero-per-repo-setup alternative, see RUNNERS.md → "Org-level runner".
#
# Run it on the always-on Mac. It uses YOUR gh auth to mint the runner's
# registration token; nothing here needs a card. Safe to re-run (skips if the
# runner dir already exists). Standing up a runner is a persistent
# code-execution surface on this machine — only run it for repos you trust.
set -euo pipefail

REPO="${1:?usage: bootstrap-runner.sh <repo> [org]}"
ORG="${2:-LX8}"
SRC="${HOME}/actions-runner"          # an existing runner = the binary source
DEST="${HOME}/actions-runner-${REPO}"
LABELS="self-hosted,macOS,X64"

command -v gh >/dev/null || { echo "❌ gh CLI not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "❌ run 'gh auth login' first"; exit 1; }
[ -x "${SRC}/config.sh" ] || { echo "❌ ${SRC} not found — need one existing runner as the binary source"; exit 1; }
[ -d "${DEST}" ] && { echo "↷ ${DEST} already exists — nothing to do"; exit 0; }

# Guard: don't create hanging jobs. Warn if the repo has no self-hosted workflow.
if ! gh api "/repos/${ORG}/${REPO}/contents/.github/workflows" --jq '.[].name' 2>/dev/null \
     | while read -r f; do gh api "/repos/${ORG}/${REPO}/contents/.github/workflows/${f}" --jq '.content' \
         | base64 -d; done | grep -q 'self-hosted'; then
  echo "⚠️  ${ORG}/${REPO} has no workflow using [self-hosted, ...] yet."
  echo "    Add one from the org templates (Actions → New workflow → 'LX8 · …')."
fi

echo "→ copying runner binary (no config/state) into ${DEST}"
mkdir -p "${DEST}"
rsync -a --exclude='_work' --exclude='_diag' --exclude='.runner' \
         --exclude='.credentials*' --exclude='.service' --exclude='.env' \
         --exclude='.path' "${SRC}/" "${DEST}/"

echo "→ minting a registration token for ${ORG}/${REPO}"
token="$(gh api -X POST "/repos/${ORG}/${REPO}/actions/runners/registration-token" --jq .token)"
[ -n "${token}" ] || { echo "❌ no token (need admin on ${REPO})"; exit 1; }

echo "→ configuring + installing the launchd service"
( cd "${DEST}" \
  && ./config.sh --url "https://github.com/${ORG}/${REPO}" --token "${token}" \
       --name "${REPO}-$(hostname -s)" --labels "${LABELS}" --work _work --unattended --replace \
  && ./svc.sh install && ./svc.sh start )

echo "→ verifying online"
gh api "/repos/${ORG}/${REPO}/actions/runners" \
  --jq '[.runners[] | select(.status=="online")] | "  ✅ \(length) online runner(s) on '"${ORG}/${REPO}"'"'
