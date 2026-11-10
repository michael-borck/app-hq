# ADR 0003: one Apple identity for the portfolio

Status: accepted.

## Decision

Use one Developer ID Application certificate and one App Store Connect API key
for all apps in the Apple team. Do not create per-app certificates or per-app
notarization passwords.

Tauri updater keys remain per app because the public key is embedded in each
app’s bundle.

Windows signing uses one shared Azure Trusted Signing account/profile when it is
rolled out.

## Consequences

- Certificate/password rotation is a fleet change, not 30 independent changes.
- Secret names are canonical across repos and synced by script.
- Losing the private key affects every app; back it up securely.
- Revoking a shared API key affects all notarization until replaced.
