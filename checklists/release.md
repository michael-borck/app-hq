# Release checklist

- [ ] Version bumped and committed.
- [ ] Tag created from the release commit.
- [ ] Tag matches package/app version.
- [ ] CI passes typecheck, lint, tests, build.
- [ ] macOS signing certificate and API key present on packaging step.
- [ ] Electron macOS runner pinned (`macos-15` at time of writing).
- [ ] Tauri updater key present if the app uses updates (per app).
- [ ] Windows signing configured if required.
- [ ] Unsigned fallback clears all Apple/notarization env vars.
- [ ] Draft release created with all platform assets.
- [ ] macOS artifact verifies with codesign/spctl/stapler.
- [ ] Windows artifact verifies with signtool (if signed).
- [ ] Release notes written.
- [ ] Draft published only after verification.
- [ ] Old app-specific password revocations handled.
