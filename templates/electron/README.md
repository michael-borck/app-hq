# Electron release template — signed and notarized

Golden pattern for the Electron fleet. It is based on the batch C Lens
repos (insight-lens, thematic-lens, lens-desktop, assessment-bench-desktop),
which include the manual `notarize-check` job. The same API-key pattern has
already been applied to batch A and batch B, plus the book-forge pilot — see
[`runbooks/signing.md`](../../runbooks/signing.md#current-fleet-state).

Use this when a repo's release workflow still uses Apple ID notarization, has
no notarization at all, or was copied from an older app.

## Files

| File | Purpose |
|---|---|
| `release.yml` | Golden GitHub Actions release workflow (tag + manual dispatch). |
| `notarize.js` | `afterSign` hook: API-key notarization with Apple ID fallback. |
| `electron-builder.yml` | The `afterSign`, hardened-runtime, and `notarize: false` settings the hook needs. |

## Copy into an app

1. Copy `notarize.js` to `scripts/notarize.js`.
2. Merge the relevant `electron-builder.yml` settings into the app's existing
   config. Keep the app's own `appId`, `productName`, targets, and file lists.
3. Copy `release.yml` to `.github/workflows/release.yml` and adapt:
   - build command (`npm run build`, `pnpm build`, etc.)
   - artifact paths and names
   - whether to publish to npm / other package managers
   - draft vs auto-published GitHub release
4. Add `@electron/notarize` to devDependencies; the afterSign hook requires it.
5. Confirm the repo has the canonical secrets (see below).
6. Test with `workflow_dispatch` before cutting a tag.

## Required secrets

Canonical names are identical across the fleet. See
[`runbooks/signing.md`](../../runbooks/signing.md) and
[`adr/0003-signing-identity.md`](../../adr/0003-signing-identity.md).

| Secret | Value |
|---|---|
| `APPLE_CERTIFICATE` | base64 `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
| `APPLE_SIGNING_IDENTITY` | `Developer ID Application: Name (TEAMID)` |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_API_KEY` | App Store Connect Key ID |
| `APPLE_API_ISSUER` | App Store Connect Issuer ID |
| `APPLE_API_KEY_CONTENT` | base64 `.p8` content |

The workflow also accepts legacy `CSC_LINK` / `CSC_KEY_PASSWORD` during
migration. Do not require `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` once the
API key is working.

## How notarization works

1. Both the tag build and `notarize-check` decode `APPLE_API_KEY_CONTENT` into
   `$RUNNER_TEMP/apple-api/AuthKey_<KEYID>.p8` and export
   `APPLE_API_KEY_PATH` through `$GITHUB_ENV`.
2. `electron-builder` signs with `CSC_LINK` / `CSC_KEY_PASSWORD` and packages
   `--arm64`.
3. The `afterSign` hook (`scripts/notarize.js`) runs `notarytool` with the API
   key and staples the ticket.
4. `mac.notarize: false` is intentional: electron-builder's built-in
   notarization wrapper must not run a second time.

If the API key secrets are absent, the hook falls back to
`NOTARIZE_APPLE_*` / Apple ID. If the signing certificate is absent, the
workflow clears every Apple/notarization variable and builds unsigned rather
than failing inside the hook.

## Runner pin

Use **`macos-15`** for Electron, and build arm64 explicitly:

```bash
npx electron-builder --mac --arm64 --publish never
```

`macos-latest` has moved to macOS 26 and breaks electron-builder 24's
temporary-keychain import. `macos-14` is retired.

## Tag vs manual dispatch

- **Tag push** runs the full path: create/reuse the draft release → build and
  upload every platform → flip the draft to live.
- **Manual dispatch** runs only `notarize-check`: build, sign, notarize, and
  verify a single arm64 zip with `--publish never`. It does not create a
  release or upload assets. Use it after rotating Apple credentials or
  renewing the developer membership.
- A tag captures the workflow at that commit. Re-running an old tag does not
  pick up later workflow changes; cut a new patch tag instead.

## Release gate

Gate packaging on the normal CI checks so a tag cannot publish a broken build.
In playable-lessons, `release.yml` calls `./.github/workflows/ci.yml` as a
`preflight` job and the build job declares `needs: preflight`. Add
`workflow_call:` to the CI workflow's `on:` block.

## Verify before publishing

The `notarize-check` job does this automatically:

```bash
codesign --verify --deep --strict --verbose=2 "App.app"
xcrun stapler validate "App.app"
spctl --assess --type execute --verbose=2 "App.app"
```

`spctl` should report “Notarized Developer ID”. You can also run the same
commands manually on a macOS machine. The release checklist lives at
[`checklists/release.md`](../../checklists/release.md).
