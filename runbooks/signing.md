# Signing and notarization runbook

Status: 2026-11-10. Apple secrets synced to all 30 desktop repos. book-forge is
the verified Electron pilot; lesson-loom v0.3.1 is the verified Tauri pilot.

## Model

- **One Developer ID Application certificate** per Apple team signs every app.
- **One App Store Connect API key** notarizes every app.
- **One app-specific password** at most, as a transition fallback. App-specific
  passwords belong to the Apple ID, not the app.
- **Per-app keys only for Tauri updater signing** (`TAURI_SIGNING_PRIVATE_KEY`
  / `_PASSWORD`); never sync or share those.
- Windows: prefer **Azure Trusted Signing** with GitHub OIDC; SignPath is a good
  alternative for OSS.

## Canonical secret names

| Secret | Value |
|---|---|
| `APPLE_CERTIFICATE` | base64 `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
| `APPLE_SIGNING_IDENTITY` | `Developer ID Application: Name (TEAMID)` |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_API_KEY` | App Store Connect Key ID |
| `APPLE_API_ISSUER` | App Store Connect Issuer ID |
| `APPLE_API_KEY_CONTENT` | base64 `.p8` |

Transitional legacy names (Electron): `CSC_LINK`, `CSC_KEY_PASSWORD`,
`APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`.

## Local credentials

Keep outside all repos:

```text
~/.certs/
  Certificates.p12
  AuthKey_<KEYID>.p8
  apple.env            # non-password values, 0600
```

- Directory `0700`; files `0600`.
- Do not store the `.p12` password in `apple.env` unless you accept plaintext;
  read it with `read -rs` when running the sync.
- The `.p12` password is the one chosen during Keychain Access export, not the
  macOS login password.
- The `.p8` has no password.

## Creating credentials

1. **Certificate:** Apple Developer → Certificates, Identifiers & Profiles →
   Developer ID Application. Import the `.cer` into Keychain Access, confirm the
   private key is nested under **My Certificates**, then export the certificate
   as `.p12` with a new password.
2. **API key:** App Store Connect → Users and Access → Integrations → Team Keys
   → add a key with Developer access. Download `AuthKey_<KEYID>.p8` once. Record
   the Key ID and the Issuer ID shown above the table.
3. **Team ID:** Apple Developer → Membership details, or the certificate subject.

## Syncing secrets across repos

`scripts/sync-apple-secrets.sh` populates canonical + legacy names across
`scripts/apple-signing-repos.txt`. Dry run by default.

```bash
set -a; source ~/.certs/apple.env; set +a
read -rs "?New .p12 password: " APPLE_CERTIFICATE_PASSWORD; echo
export APPLE_CERTIFICATE_PASSWORD

scripts/sync-apple-secrets.sh --check
scripts/sync-apple-secrets.sh
scripts/sync-apple-secrets.sh --apply
```

The script also reads `~/.certs/apple.env` itself, so the `source` above is
optional. The `.p12` password is the one value it will not read from a file.

`michael-borck` is a personal account, so per-repo secrets are required. The
`retroverse-studios` repos could move to org-level secrets later.

## Electron workflow pattern

### Shared implementation

`.github/workflows/electron-release.yml` owns the matrix, prepare/publish,
artifact upload, sidecar hook, and manual notarize-check. Callers pass
`product-name`, `package-command`, and optional `project-path`,
`install-command`, `setup-command`, `build-command`, `sidecar-command`,
`preflight-command`, `matrix`, `notarize-check-command`, and `publish-mode`.
Use [`templates/electron/release.yml`](../templates/electron/release.yml) as the
thin caller. The Apple action writes `APPLE_API_KEY_PATH` for the afterSign
hook; custom workflows must do the same.

### Custom signing modes

Three modes are supported; all use the same Developer ID and API key:

- **Standard** (`signing-mode: standard`, default): the workflow sets
  `CSC_LINK`/`CSC_KEY_PASSWORD`; electron-builder imports the certificate into
  its temporary keychain and signs the `.app`; `scripts/notarize.js`
  (`notarize-mode: hook`) notarizes and staples the `.app`.
- **Custom keychain** (`signing-mode: custom`): the shared
  `electron-keychain` action creates a persistent `build.keychain`, imports the
  certificate, and sets it as default. `CSC_LINK` is empty, so electron-builder
  uses that identity instead of creating its own temporary keychain. Use
  `notarize-mode: hook` when the app has `scripts/notarize.js`, or
  `notarize-mode: builtin` when it relies on electron-builder's notarization.
  This exists because electron-builder's temporary-keychain import can fail on
  current macOS runners (`SecKeychainUnlock`).
- **DMG notarization** (`signing-mode: custom`, `notarize-mode: none`,
  `publish-mode: artifacts`, plus `post-package-command`): electron-builder
  packages with `--publish never`; the post-package command signs, notarizes,
  and staples the `.dmg` container before the artifacts are uploaded. Use a
  custom `notarize-check-verify` that validates the DMG.

The shared workflow uses `CSC_LINK` only in standard mode and leaves the
keychain alone in custom mode. The app keeps its own afterSign hook or DMG
script; the matrix, release, and manual check remain shared.

### Optional: DMG container signing/stapling

The app notarization covers the `.app` and the normal first-launch Gatekeeper
prompt. The disk image can additionally be signed, notarized, and stapled with
the opt-in `.github/actions/notarize-dmg` composite action. That makes the DMG
itself pass `spctl` and validate offline; it is not required for the app to
launch and does not change the first-launch prompt.

```yaml
# after packaging, before artifacts are uploaded
- uses: michael-borck/app-hq/.github/actions/notarize-dmg@main
  with:
    target-dir: release
```

It expects `APPLE_SIGNING_IDENTITY`, the `.p8` path, key ID, and issuer in the
environment (the `apple-signing` / `electron-keychain` actions set these) and
fails when there are DMGs but credentials are missing. It is **not** wired into
the shared release workflow yet; decide per app.

Ordering and caveats:

- Run it after packaging and before upload. With `publish-mode: builder`,
  electron-builder publishes during the package step, so the uploaded DMG
  would be unstapled; use `publish-mode: artifacts` or a custom workflow.
- Each DMG adds another notary submission per arch.
- Stapling changes the DMG hash after `*.dmg.blockmap` / `latest-mac.yml` are
  generated. macOS auto-update uses the ZIP, not the DMG; do not use the DMG
  as the update artifact, or regenerate its metadata.
- The DMG must be final before stapling; later edits invalidate the ticket.
- The app inside must already be signed and notarized.

See [`../.github/actions/notarize-dmg/README.md`](../.github/actions/notarize-dmg/README.md).

The underlying pattern sets canonical values on the packaging step:

```yaml
env:
  CSC_LINK: ${{ secrets.APPLE_CERTIFICATE || secrets.CSC_LINK }}
  CSC_KEY_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD || secrets.CSC_KEY_PASSWORD }}
  APPLE_API_KEY: ${{ secrets.APPLE_API_KEY }}
  APPLE_API_ISSUER: ${{ secrets.APPLE_API_ISSUER }}
```

Before packaging, write the API key:

```bash
mkdir -p "$RUNNER_TEMP/apple-api"
printf '%s' "$APPLE_API_KEY_CONTENT" | openssl base64 -d -A \
  > "$RUNNER_TEMP/apple-api/AuthKey_${APPLE_API_KEY}.p8"
echo "APPLE_API_KEY_PATH=$RUNNER_TEMP/apple-api/AuthKey_${APPLE_API_KEY}.p8" >> "$GITHUB_ENV"
```

The afterSign hook should prefer:

```js
notarize({
  tool: 'notarytool',
  appPath,
  appleApiKey: process.env.APPLE_API_KEY_PATH,
  appleApiKeyId: process.env.APPLE_API_KEY,
  appleApiIssuer: process.env.APPLE_API_ISSUER,
});
```

Fallback to `NOTARIZE_APPLE_*` only during migration.

### macOS runner pin

`macos-14` is retired. `macos-latest` is now macOS 26, where electron-builder
24's automatic temporary-keychain import fails with:

```text
security: SecKeychainUnlock: The user name or passphrase you entered is not correct.
```

Pin Electron packaging to **`macos-15`** and build arm64 explicitly:

```yaml
- os: macos-15
  platform: mac
```

```bash
npx electron-builder --mac --arm64 --publish never
```

book-forge run 42762263662 verified with `codesign --verify`,
`spctl --assess`, and `xcrun stapler validate`. `spctl` reported
“Notarized Developer ID”.

### Manual credential check (`notarize-check`)

Batch C repos include a `workflow_dispatch`-only `notarize-check` job. It
builds a single arm64 macOS zip with `--publish never`, signs and notarizes it,
then verifies:

```bash
codesign --verify --deep --strict --verbose=2 "App.app"
xcrun stapler validate "App.app"
spctl --assess --type execute --verbose=2 "App.app"
```

It does **not** create a release or upload assets, so it is safe to run after
rotating the API key, renewing the developer membership, or changing the
signing certificate. The release jobs are tag-gated; a manual dispatch only
runs the credential check. Use the shared workflow and the template caller as the starting point.

A tag captures the workflow at that commit. Re-running an old tag will not pick
up a later workflow or notarization change; cut a new patch tag instead.

## Tauri workflow pattern

### Shared implementation

The fleet implementation is in
[`michael-borck/app-hq`](https://github.com/michael-borck/app-hq):

- `tauri-release.yml` — tag push runs preflight → macOS arm64/Intel, Ubuntu
  22.04, Windows → API-key signing/notarization → draft release → publish.
  Manual dispatch runs **notarize-check only**.
- `apple-signing` — validates the canonical secrets and writes the `.p8` to
  `~/.appstoreconnect/private_keys`.

Nested Tauri apps set `project-path` to the directory containing `src-tauri`.
If that directory has no `package.json`, also set
`tauri-script: npx --yes @tauri-apps/cli@^2` and leave `install-command`/`cache`
empty. Extra release assets (standalone HTML, stable bundle names) belong in a
job with `needs: release` that attaches them after publish.

pnpm workspace apps use `install-command: corepack enable && pnpm install
--frozen-lockfile`, `cache: ''`, and `build-command` for the workspace build.
Sidecar apps use `setup-command`/`build-command` for their backend build/sign
step; `build-command` runs on every platform after Apple signing and receives
`TAURI_TARGET`. Apps with a release overlay pass
`notarize-args: --config src-tauri/tauri.release.conf.json` so the manual check
uses the same external binaries. `HF_TOKEN` is optional for model downloads.
Azure Windows signing is not part of the shared workflow; Windows builds are
unsigned unless added separately.

Caller:

```yaml
jobs:
  release:
    uses: michael-borck/app-hq/.github/workflows/tauri-release.yml@main
    with:
      product-name: App
      preflight-command: npm run typecheck && npm run lint && npm test
      updater: true
    secrets:
      APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
      APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
      APPLE_SIGNING_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
      APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
      APPLE_API_KEY: ${{ secrets.APPLE_API_KEY }}
      APPLE_API_ISSUER: ${{ secrets.APPLE_API_ISSUER }}
      APPLE_API_KEY_CONTENT: ${{ secrets.APPLE_API_KEY_CONTENT }}
      TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
      TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}
```

`secrets: inherit` only works within the same organization or enterprise. Use the
named mapping for `retroverse-studios` or any other owner.

The underlying pattern the shared workflow implements:

```yaml
env:
  APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
  APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
  APPLE_SIGNING_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
  APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  APPLE_API_KEY: ${{ secrets.APPLE_API_KEY }}
  APPLE_API_ISSUER: ${{ secrets.APPLE_API_ISSUER }}
```

Before `tauri-action`:

```bash
mkdir -p ~/.appstoreconnect/private_keys
printf '%s' "$APPLE_API_KEY_CONTENT" | openssl base64 -d -A \
  > ~/.appstoreconnect/private_keys/AuthKey_${APPLE_API_KEY}.p8
```

Tauri searches that default directory. Do not set `APPLE_ID`/`APPLE_PASSWORD`
once API-key notarization is in place.

### PyInstaller / sidecar bundles

Tauri signs the app, but it does not reliably sign Mach-O files shipped as
bundled resources. Sign every Mach-O in the sidecar before `tauri build`:

```bash
while IFS= read -r -d '' file; do
  file "$file" | grep -q 'Mach-O' || continue
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$file"
done < <(find src-tauri/sidecar -type f -print0)
```

If PyInstaller uses the runner's Homebrew Python, it emits `Python.framework`.
Tauri's resource copy dereferences that framework's symlinks, which invalidates
the framework signature and fails notarization with "signature of the binary is
invalid". Force uv's standalone CPython instead:

```yaml
env:
  UV_PYTHON_PREFERENCE: only-managed
```

That emits `libpython3.12.dylib` (a plain Mach-O) instead of a framework. Keep
`UV_PYTHON_PREFERENCE` at job level so `uv sync` and `pyinstaller` agree.

## Unsigned fallback

When signing is unavailable or broken:

- unset `CSC_LINK`, `CSC_KEY_PASSWORD`
- unset `NOTARIZE_APPLE_*`
- unset `APPLE_API_KEY_PATH`, `APPLE_API_KEY`, `APPLE_API_ISSUER`,
  `APPLE_API_KEY_CONTENT`
- set `CSC_IDENTITY_AUTO_DISCOVERY=false`
- build and publish an unsigned artifact with a loud warning

Never let the afterSign hook run against an unsigned app; it will fail and can
mask the real build result.

## Verification

```bash
codesign --verify --deep --strict --verbose=2 "App.app"
spctl --assess --type execute --verbose=4 "App.app"
xcrun stapler validate "App.app"

openssl pkcs12 -info -in ~/.certs/Certificates.p12 -noout -legacy
openssl pkcs12 -in ~/.certs/Certificates.p12 -nocerts -noenc -legacy | openssl pkey -noout
```

The second `openssl` command prints nothing on success and confirms the private
key is present.

## Rotation

- Certificate expiry: Developer ID certificates are time-limited; renew before
  expiry and re-export a fresh `.p12`.
- Password exposure: re-export the same identity with a new password. A new
  certificate is only needed if the private key itself is compromised.
- App-specific password exposure: revoke at `appleid.apple.com`; create a single
  replacement fallback if legacy workflows still need it.
- API key exposure: revoke the App Store Connect key, create a new one, update
  `APPLE_API_KEY`, `APPLE_API_ISSUER`, `APPLE_API_KEY_CONTENT`.

## Current fleet state

- All 30 repos have canonical Apple secrets.
- book-forge: Electron pilot signed + notarized with API key on `macos-15`.
- Electron batch A: debrief, cabinet, career-compass verified with API-key
  notarization on `macos-15` (cabinet and career-compass DMGs checked with
  spctl/stapler).
- Electron batch B: playable-lessons, study-buddy, talk-buddy verified with
  API-key notarization on `macos-15`.
- Electron batch C: insight-lens, thematic-lens, lens-desktop,
  assessment-bench-desktop verified with API-key notarization on `macos-15`.
  These now have a `notarize-check` workflow_dispatch job that signs, notarizes,
  and verifies without creating a release.
- Electron batch D: character-craft-lite, feed-forward-desktop,
  assessment-lens-desktop, curriculum-curator verified.
- cite-sight: manual DMG notarization rewritten to the API key and verified.
- honeyguide: the Electron app formerly mis-filed under `bowerbird`; now
  verified with API-key notarization on `macos-15` (notarize-check passed).
- bowerbird: Python-only bookmark tool, not a desktop app; removed from the
  Apple signing list and its Apple secrets were deleted.

### Keychain auto-lock

If a workflow imports the certificate into a temporary `build.keychain` and then
spends 10+ minutes building before signing, unlock it for the whole job:

```bash
security create-keychain -p actions build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p actions build.keychain
security set-keychain-settings -lut 21600 build.keychain
```

Without the timeout, codesign can hang on a locked keychain; study-buddy hit
this and needed a 15-minute retry timeout to expose it.
- lesson-loom: Tauri pilot verified on v0.3.1 (both macOS arches notarized;
  `spctl` reports Notarized Developer ID).
- Tauri batch A: limn, slide-stream, ethos-mirror, document-lens verified with
  API-key notarization. limn/slide-stream/ethos-mirror support manual dispatch
  with artifact uploads; document-lens creates a draft release on dispatch.
- Tauri batch B: numeron and astron verified with API-key notarization. Their
  per-app updater keys remain in place.
- Tauri batch C: venture-lab and karaoke-stage verified with API-key
  notarization. video-to-guide verified 2026-11-11 after signing its bundled
  PyInstaller sidecar; its Intel backend test is skipped (OpenCV VideoWriter
  fails on macos-15-intel). Knotebook is on the shared workflow; v0.1.6 was
  released through it on 2026-11-15. case-crafter is archived; cairn has no
  desktop release workflow.
- Knotebook: Tauri; v0.1.6 released 2026-11-15 through the shared app-hq
  workflow. All four matrix legs built; both macOS arches signed/notarized,
  and `latest.json` reports 0.1.6. The repo slug is lowercase
  (`michael-borck/knotebook`); PWA auto-deploys on pushes to `main`.
- Legacy `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` remain in some repos until
  migration; revoke exposed app-specific passwords after the Electron batch
  migration or after installing one new fallback.
