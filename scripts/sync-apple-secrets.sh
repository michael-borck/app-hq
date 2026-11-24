#!/usr/bin/env bash
#
# Populate Apple signing secrets across the app portfolio.
#
# Defaults to a dry run. Use --apply to write secrets with `gh secret set`.
# Uses the canonical names from docs/SIGNING.md and also sets the legacy
# Electron names during the transition, so existing workflows keep working.
#
# Tauri updater keys (TAURI_SIGNING_PRIVATE_KEY[_PASSWORD]) are per app and are
# deliberately NOT touched by this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_FILE="$SCRIPT_DIR/apple-signing-repos.txt"
CONFIG_FILE="${APPLE_SIGNING_CONFIG:-$HOME/.certs/apple.env}"
APPLY=0
CHECK=0
TYPE_FILTER=""

usage() {
  cat <<'EOF'
Usage: sync-apple-secrets.sh [options]

Options:
  --apply              Actually set secrets (default: dry run)
  --check              Report which canonical secrets are missing
  --repos FILE         Repo list (default: apple-signing-repos.txt)
  --config FILE        Local signing env file (default: ~/.certs/apple.env)
  --type electron|tauri
  -h, --help

Required for --apply:
  APPLE_CERTIFICATE_P12        path to Developer ID Application .p12
  APPLE_CERTIFICATE_PASSWORD   .p12 export password
  APPLE_SIGNING_IDENTITY       "Developer ID Application: Name (TEAMID)"
  APPLE_TEAM_ID                Apple team id
  APPLE_API_KEY_P8             path to App Store Connect AuthKey_*.p8
  APPLE_API_KEY                App Store Connect Key ID
  APPLE_API_ISSUER             App Store Connect Issuer ID

Optional during transition (legacy Apple ID notarization):
  APPLE_ID
  APPLE_APP_SPECIFIC_PASSWORD

Values are also read from ~/.certs/apple.env (or --config), one per line, in
KEY=value form with or without export, and never override the environment:
  APPLE_CERTIFICATE_P12        path to the .p12 (default ~/.certs/Certificates.p12)
  APPLE_SIGNING_IDENTITY       "Developer ID Application: Name (TEAMID)"
  APPLE_TEAM_ID                Apple team id
  APPLE_API_KEY_P8             path to App Store Connect AuthKey_*.p8
  APPLE_API_KEY                App Store Connect Key ID
  APPLE_API_ISSUER             App Store Connect Issuer ID

The .p12 password is not read from the file: pass it in the environment
(read -rs), as runbooks/signing.md describes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --check) CHECK=1 ;;
    --repos) REPOS_FILE="${2:?missing file}"; shift ;;
    --config) CONFIG_FILE="${2:?missing file}"; shift ;;
    --type) TYPE_FILTER="${2:?missing type}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

command -v gh >/dev/null || { echo "gh is required" >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
[[ -f "$REPOS_FILE" ]] || { echo "Repo list not found: $REPOS_FILE" >&2; exit 1; }

b64() { openssl base64 -A -in "$1"; }

# Fill in any variable the environment has not provided, from an env file:
# KEY=value per line, "export " allowed, surrounding quotes and a leading ~ handled.
load_env_file() {
  local file="$1" line key value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"
      value="${BASH_REMATCH[3]}"
      case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
      esac
      # Paths are written as "~/…" or "$HOME/…"; expand both, without eval.
      value="${value//\$\{HOME\}/$HOME}"
      value="${value//\$HOME/$HOME}"
      case "$value" in
        "~"*) value="$HOME${value#\~}" ;;
      esac
      [[ -n "${!key:-}" ]] || printf -v "$key" '%s' "$value"
    fi
  done < "$file"
}

load_env_file "$CONFIG_FILE"
APPLE_CERTIFICATE_P12="${APPLE_CERTIFICATE_P12:-$HOME/.certs/Certificates.p12}"
if [[ -n "${APPLE_API_KEY:-}" ]]; then
  APPLE_API_KEY_P8="${APPLE_API_KEY_P8:-$HOME/.certs/AuthKey_${APPLE_API_KEY}.p8}"
fi

if [[ -z "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  APPLE_SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1 || true)"
fi

CERT_B64=""
KEY_B64=""
if [[ "$APPLY" -eq 1 ]]; then
  : "${APPLE_CERTIFICATE_P12:?set APPLE_CERTIFICATE_P12 or add it to the config}"
  : "${APPLE_CERTIFICATE_PASSWORD:?set APPLE_CERTIFICATE_PASSWORD or add it to the config}"
  : "${APPLE_SIGNING_IDENTITY:?set APPLE_SIGNING_IDENTITY or add it to the config}"
  : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID or add it to the config}"
  : "${APPLE_API_KEY_P8:?set APPLE_API_KEY_P8 or add it to the config}"
  : "${APPLE_API_KEY:?set APPLE_API_KEY or add API Key ID to the config}"
  : "${APPLE_API_ISSUER:?set APPLE_API_ISSUER or add API Issuer ID to the config}"
  [[ -f "$APPLE_CERTIFICATE_P12" ]] || { echo "Missing .p12: $APPLE_CERTIFICATE_P12" >&2; exit 1; }
  [[ -f "$APPLE_API_KEY_P8" ]] || { echo "Missing .p8: $APPLE_API_KEY_P8" >&2; exit 1; }
  CERT_B64="$(b64 "$APPLE_CERTIFICATE_P12")"
  KEY_B64="$(b64 "$APPLE_API_KEY_P8")"
fi

CANONICAL=(
  APPLE_CERTIFICATE
  APPLE_CERTIFICATE_PASSWORD
  APPLE_SIGNING_IDENTITY
  APPLE_TEAM_ID
  APPLE_API_KEY
  APPLE_API_ISSUER
  APPLE_API_KEY_CONTENT
)

set_secret() {
  local repo="$1" name="$2" value="$3"
  if [[ "$APPLY" -eq 1 ]]; then
    printf '%s' "$value" | gh secret set "$name" -R "$repo" >/dev/null
    echo "  set $name"
  else
    echo "  would set $name"
  fi
}

check_repo() {
  local repo="$1" kind="$2"
  local existing missing=()
  existing="$(gh secret list -R "$repo" 2>/dev/null | cut -f1 || true)"
  for name in "${CANONICAL[@]}"; do
    grep -qx "$name" <<<"$existing" || missing+=("$name")
  done
  if [[ "$kind" == "electron" ]]; then
    for name in CSC_LINK CSC_KEY_PASSWORD; do
      grep -qx "$name" <<<"$existing" || missing+=("$name")
    done
  fi
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "OK   $repo"
  else
    echo "MISS $repo: ${missing[*]}"
  fi
}

count=0
missing_total=0
while read -r repo kind _rest; do
  [[ -z "${repo:-}" || "$repo" == \#* ]] && continue
  [[ -n "$TYPE_FILTER" && "$kind" != "$TYPE_FILTER" ]] && continue
  count=$((count + 1))

  if [[ "$CHECK" -eq 1 ]]; then
    check_repo "$repo" "$kind" || missing_total=$((missing_total + 1))
    continue
  fi

  echo
  echo "$repo ($kind)"
  set_secret "$repo" APPLE_CERTIFICATE "$CERT_B64"
  set_secret "$repo" APPLE_CERTIFICATE_PASSWORD "${APPLE_CERTIFICATE_PASSWORD:-}"
  set_secret "$repo" APPLE_SIGNING_IDENTITY "${APPLE_SIGNING_IDENTITY:-}"
  set_secret "$repo" APPLE_TEAM_ID "${APPLE_TEAM_ID:-}"
  set_secret "$repo" APPLE_API_KEY "${APPLE_API_KEY:-}"
  set_secret "$repo" APPLE_API_ISSUER "${APPLE_API_ISSUER:-}"
  set_secret "$repo" APPLE_API_KEY_CONTENT "$KEY_B64"

  if [[ "$kind" == "electron" ]]; then
    # Transition: existing workflows still read these names.
    set_secret "$repo" CSC_LINK "$CERT_B64"
    set_secret "$repo" CSC_KEY_PASSWORD "${APPLE_CERTIFICATE_PASSWORD:-}"
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    set_secret "$repo" APPLE_ID "$APPLE_ID"
    set_secret "$repo" APPLE_APP_SPECIFIC_PASSWORD "$APPLE_APP_SPECIFIC_PASSWORD"
  fi
done < "$REPOS_FILE"

echo
if [[ "$CHECK" -eq 1 ]]; then
  echo "Checked $count repos."
  exit 0
fi

if [[ "$APPLY" -eq 1 ]]; then
  echo "Updated $count repos."
else
  echo "Dry run for $count repos. Re-run with --apply to write secrets."
fi
