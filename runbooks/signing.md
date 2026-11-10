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

`michael-borck` is a personal account, so per-repo secrets are required. The
`retroverse-studios` repos could move to org-level secrets later.

## Electron workflow pattern

Set canonical values on the packaging step:

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
runs the credential check. Use
[`templates/electron/release.yml`](../templates/electron/release.yml) as the
starting point.

A tag captures the workflow at that commit. Re-running an old tag will not pick
up a later workflow or notarization change; cut a new patch tag instead.

## Tauri workflow pattern

```yaml
env:
  APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
  APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
  APPLE_SIGNING_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
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
  notarization on `macos-15` (career-compass DMG checked with spctl/stapler).
- Electron batch B: playable-lessons, study-buddy, talk-buddy verified with
  API-key notarization on `macos-15`.
- Electron batch C: insight-lens, thematic-lens, lens-desktop,
  assessment-bench-desktop verified with API-key notarization on `macos-15`.
  These now have a `notarize-check` workflow_dispatch job that signs, notarizes,
  and verifies without creating a release.
- Electron batch D: character-craft-lite, feed-forward-desktop,
  assessment-lens-desktop, curriculum-curator verified.
- cite-sight: manual DMG notarization rewritten to the API key and verified.
- bowerbird: blocked. `origin/main` was force-rewritten to a Python-only project
  with no `packages/desktop` package; the old local history is preserved on
  `backup/bowerbird-local-2026-11-10`. Reconcile the repo before signing.

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
- Legacy `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` remain in some repos until
  migration; revoke exposed app-specific passwords after the Electron batch
  migration or after installing one new fallback.
