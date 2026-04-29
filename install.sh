#!/usr/bin/env bash
# install-booster.sh — one-shot macOS installer for Booster.
#
# Usage (paste into Terminal):
#   curl -fsSL https://raw.githubusercontent.com/Vlad-Ai-gg/booster-dist/main/install.sh | bash
#
# Why this exists: macOS Gatekeeper's "is damaged" / "cannot be opened" warning
# is triggered by the `com.apple.quarantine` extended attribute that Safari,
# Chrome, Slack, Drive Desktop and friends stamp onto everything they download.
# `curl` does NOT stamp it, so anything we fetch here is clean from the start.
# That means the user never has to run `xattr -cr Booster.app/` by hand.
#
# Override the download base at invocation:
#   BOOSTER_BASE_URL=https://my-host/path bash install.sh

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
# Stable URL — github.com/.../releases/latest/download always resolves to the
# most recent published release's asset. Bump the release tag without touching
# this URL or the curl one-liner.
BASE_URL="${BOOSTER_BASE_URL:-https://github.com/Vlad-Ai-gg/booster-dist/releases/latest/download}"
APP_NAME="Booster.app"
INSTALL_DIR="/Applications"

# ── Sanity checks ──────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer runs on macOS only." >&2
  exit 1
fi

case "$(uname -m)" in
  arm64)  dmg_url="${BASE_URL}/Booster_aarch64.dmg" ;;
  x86_64) dmg_url="${BASE_URL}/Booster_x64.dmg" ;;
  *)      echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# ── Workspace ──────────────────────────────────────────────────────────────
work="$(mktemp -d)"
# Always tear down: detach mount (may already be gone), remove temp dir.
trap 'hdiutil detach "$work/mnt" -quiet >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

# ── Download ───────────────────────────────────────────────────────────────
echo "Downloading $dmg_url"
if ! curl -fSL --progress-bar -o "$work/booster.dmg" "$dmg_url"; then
  echo "Download failed. Verify BOOSTER_BASE_URL and your network." >&2
  exit 1
fi

# ── Quit any running instance ──────────────────────────────────────────────
# cp -R into a busy bundle fails with "Resource busy"; close cleanly first.
if pgrep -x Booster >/dev/null 2>&1; then
  echo "Closing running Booster…"
  osascript -e 'tell application "Booster" to quit' >/dev/null 2>&1 || true
  sleep 1
fi

# ── Mount & copy ───────────────────────────────────────────────────────────
mkdir -p "$work/mnt"
hdiutil attach "$work/booster.dmg" -nobrowse -mountpoint "$work/mnt" -quiet

src="$work/mnt/$APP_NAME"
if [[ ! -d "$src" ]]; then
  echo "$APP_NAME not found inside the DMG." >&2
  exit 1
fi

dest="$INSTALL_DIR/$APP_NAME"
echo "Installing to $dest"
# /Applications is admin-writable on most setups, so direct cp works without
# sudo. Fall back to sudo only when the direct path fails — that way the user
# is prompted for password ONLY when they actually need it.
if [[ -d "$dest" ]]; then
  rm -rf "$dest" 2>/dev/null || sudo rm -rf "$dest"
fi
cp -R "$src" "$INSTALL_DIR/" 2>/dev/null || sudo cp -R "$src" "$INSTALL_DIR/"

hdiutil detach "$work/mnt" -quiet

echo "Done. Launching…"
open "$dest"
