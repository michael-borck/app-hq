# Release runbook

## Runners

| Stack | macOS | Windows | Linux |
|---|---|---|---|
| Electron | `macos-15`, `--arm64` | `windows-latest` | `ubuntu-latest` |
| Tauri | `macos-latest` (verify) or `macos-15` | `windows-latest` | `ubuntu-22.04` |
| PWA/web | n/a | n/a | `ubuntu-latest` |

Do not assume `macos-latest` is safe for Electron packaging. It moved to
macOS 26 and broke electron-builder 24's temporary-keychain import. Pin
`macos-15` for Electron until the toolchain is upgraded and tested.

## Tag and version rules

- Version bump commit: `chore: release vX.Y.Z`.
- Annotated tag: `git tag -a vX.Y.Z -m "Product vX.Y.Z"`.
- Tag matches `package.json`/`tauri.conf.json` version.
- Draft release by default; publish after all platform assets are attached.
- Never reuse a tag for a different commit. If CI failed and no release was
  created, force-updating the tag is acceptable; otherwise cut a new patch.
- A tag captures the workflow at that commit. Re-running an old tag does not
  pick up later workflow/notarization changes; cut a new patch tag.
- A manual `workflow_dispatch` run is for the `notarize-check` credential test
  only. It should not create a release or publish packages.

## Standard release jobs

1. Checkout + Node/Rust/Python setup.
2. Install dependencies.
3. Typecheck, lint, tests.
4. Build renderer/CLI.
5. Package installers per platform.
6. Sign and notarize (macOS); sign Windows when configured.
7. Upload artifacts.
8. Create draft release.
9. Verify one artifact from each platform.
10. Publish release.

## Artifact verification

macOS:

```bash
codesign --verify --deep --strict --verbose=2 App.app
spctl --assess --type execute --verbose=4 App.app
xcrun stapler validate App.app
```

Windows:

```powershell
signtool verify /pa /v Installer.exe
```

Linux:

```bash
sha256sum App.AppImage
```

## Release checklist

- [ ] Version bump committed.
- [ ] Tag matches version.
- [ ] Secrets present on the packaging step.
- [ ] macOS runner pinned for Electron.
- [ ] Unsigned fallback does not run notarization.
- [ ] Draft release contains all platforms.
- [ ] One artifact per platform verified.
- [ ] Release notes mention breaking changes.
- [ ] Legacy secrets not required by this workflow.
