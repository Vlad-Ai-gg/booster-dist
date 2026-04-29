# booster-dist

Public distribution endpoint for the [Booster](https://github.com/Vlad-Ai-gg/booster-dist) macOS installer.

## Install on macOS

```sh
curl -fsSL https://raw.githubusercontent.com/Vlad-Ai-gg/booster-dist/main/install.sh | bash
```

The installer downloads the appropriate DMG for your CPU (Intel / Apple Silicon), copies the app into `/Applications`, and launches it. No `xattr`, no Gatekeeper "is damaged" warning.

`curl` does not stamp the `com.apple.quarantine` attribute that Safari, Chrome, Slack and Drive Desktop attach to downloads — so the DMG fetched by this script arrives clean.

## Releasing a new build

1. `cargo tauri build` (and `--target x86_64-apple-darwin` if shipping Intel) in the main repo.
2. Rename the produced DMGs to the stable filenames `install.sh` expects: `Booster_aarch64.dmg`, `Booster_x64.dmg`.
3. Create a new GitHub release here with tag `vX.Y.Z` and attach the DMGs as assets.

The install URL never has to change between versions — `releases/latest/download/<file>` always resolves to the most recent release.
