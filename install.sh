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
# Replace this URL with wherever your team hosts the artifacts (S3, Nextcloud,
# internal HTTP server, etc.). The script expects two files at this base:
#   <BASE>/Booster_aarch64.dmg   — Apple Silicon
#   <BASE>/Booster_x64.dmg       — Intel
BASE_URL="${BOOSTER_BASE_URL:-https://github.com/Vlad-Ai-gg/booster-dist/releases/latest/download}"
APP_NAME="Booster-Voice.app"
LEGACY_APP_NAME="Booster.app"
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
# Match both the new (Booster-Voice) and legacy (Booster) process names so
# upgrades from older installs don't trip over a still-running old binary.
for proc in Booster-Voice Booster; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    echo "Closing running $proc…"
    osascript -e "tell application \"$proc\" to quit" >/dev/null 2>&1 || true
    sleep 1
  fi
done

# Remove legacy bundle so users don't end up with two copies in /Applications.
legacy_dest="$INSTALL_DIR/$LEGACY_APP_NAME"
if [[ -d "$legacy_dest" ]]; then
  echo "Removing legacy $LEGACY_APP_NAME"
  rm -rf "$legacy_dest" 2>/dev/null || sudo rm -rf "$legacy_dest"
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
