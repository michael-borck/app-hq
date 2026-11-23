# Notarize DMG (opt-in)

Sign, notarize, and staple **DMG containers** on macOS. The app inside must
already be signed and notarized — this action does not replace the app's
notarization step; it covers the downloaded disk image itself so Gatekeeper
can validate it offline (`spctl` accepts the DMG, not just the `.app`).

This is **opt-in**. It is not wired into `electron-release.yml` yet; each app
can add it as a post-package step. The app notarization is what users need for
the normal first-launch "downloaded from the internet" prompt; DMG stapling is
extra polish.

## Usage (custom workflow)

```yaml
# after electron-builder has produced release/*.dmg, before artifact upload
- uses: michael-borck/app-hq/.github/actions/notarize-dmg@main
  with:
    target-dir: release
```

The action reads the normal app-hq Apple environment. The shared
`apple-signing` / `electron-keychain` actions already provide it:

| Value | Source |
|---|---|
| Developer ID identity | `APPLE_SIGNING_IDENTITY` |
| `.p8` path | `APPLE_API_KEY_PATH`, or `APPLE_API_KEY` when it is a file (builtin notarization mode) |
| Key ID | `APPLE_API_KEY_ID`, or `APPLE_API_KEY` when it is not a file (afterSign-hook mode) |
| Issuer ID | `APPLE_API_ISSUER` |

Inputs (`identity`, `api-key-path`, `api-key-id`, `api-issuer`) override the
environment. The step skips when the target directory has no DMGs; when there
are DMGs, missing credentials or a missing `.p8` **fail** the step (an app that
opts in is expected to have the Apple secrets).

## Ordering (important)

Run the action **after packaging and before artifacts are uploaded**:

- `publish-mode: artifacts` — safe: workflow uploads the post-processed DMG.
- `publish-mode: builder` — electron-builder publishes during the package
  step, so the uploaded DMG would be **unstapled**. Use artifacts mode, or
  move the stapling before the publish step.

For apps using the shared `electron-release.yml`, a `post-package-command`
already runs before the artifact upload. A future opt-in `dmg-stapling` input
could invoke this action directly.

## Caveats

- **Extra notary submission** per DMG per macOS arch (arm64 + Intel). Expect
  roughly 30 s–3 min each and another failure point in CI.
- **The DMG must be final.** Signing/stapling changes it; later edits
  invalidate the ticket. Never modify the image after this step.
- **Update metadata can go stale.** Signing/stapling changes the DMG hash
  after electron-builder generated `*.dmg.blockmap`/`latest-mac.yml`. macOS
  auto-update uses the **ZIP**, not the DMG, so this is usually harmless —
  but don't use the DMG as the update artifact, or regenerate its metadata.
- **The first-launch prompt stays.** A notarized app still shows the standard
  "downloaded from the internet, are you sure?" prompt; DMG stapling only
  validates the container.
- **App notarization is still required.** A stapled DMG around an unnotarized
  app does not make the app launchable.

## What it runs per DMG

```bash
codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl -a -vvv -t open --context context:primary-signature "$dmg"
```

See [`runbooks/signing.md`](../../../runbooks/signing.md#optional-dmg-container-signingstapling)
for the fleet context.
