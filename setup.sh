#!/usr/bin/env bash
# One-shot setup: give Claude Code read/draft access to your Gmail through a
# local MCP server, using your OWN Google Cloud OAuth client.
#
# Usage:  ./setup.sh [gcp-project-id]
#   If no project id is given, a new one named gmail-mcp-<random> is created.
#   The project needs NO billing account: the Gmail API is free.
set -euo pipefail

PKG="@gongrzhe/server-gmail-autoauth-mcp"
PKG_VERSION="1.1.11"            # pinned on purpose: this package can read your whole mailbox
REGISTRY="https://registry.npmjs.org"
CONF_DIR="$HOME/.gmail-mcp"
KEYS="$CONF_DIR/gcp-oauth.keys.json"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 0. prerequisites
for bin in node npm gcloud claude; do
  command -v "$bin" >/dev/null || die "'$bin' not found in PATH"
done
gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q . \
  || die "run 'gcloud auth login' first"

# ---------------------------------------------------------------- 1. GCP project + Gmail API
PROJECT="${1:-gmail-mcp-$RANDOM}"
if gcloud projects describe "$PROJECT" >/dev/null 2>&1; then
  say "Using existing project $PROJECT"
else
  say "Creating project $PROJECT (no billing needed)"
  gcloud projects create "$PROJECT" --name="Gmail MCP"
fi
say "Enabling Gmail API"
gcloud services enable gmail.googleapis.com --project="$PROJECT"

# ---------------------------------------------------------------- 2. OAuth client (manual, console only)
mkdir -p "$CONF_DIR" && chmod 700 "$CONF_DIR"
if [[ ! -f "$KEYS" ]]; then
  URL="https://console.cloud.google.com/auth/overview?project=$PROJECT"
  cat <<EOF

The OAuth client can't be created from gcloud, so do this in the browser:
  1. Get started -> app name: anything, audience: External, contact: your email
  2. Audience -> Test users -> add the Gmail address you want to connect
  3. Clients -> Create client -> type "Desktop app"
     (leave "use this client for AI agents" UNCHECKED) -> Download JSON
Opening: $URL
EOF
  command -v open >/dev/null && open "$URL" || true

  say "Waiting for ~/Downloads/client_secret_*.json (Ctrl+C to abort)"
  shopt -s nullglob
  while :; do
    files=("$HOME"/Downloads/client_secret_*.json)
    if (( ${#files[@]} )); then
      # shellcheck disable=SC2012  # names are client_secret_<id>.json, no odd chars
      newest=$(ls -t "${files[@]}" | head -1)
      break
    fi
    sleep 3
  done
  node -e "const d=require(process.argv[1]); if(!d.installed) process.exit(1)" "$newest" \
    || die "$newest is not a Desktop-app client (missing 'installed' key)"
  cp "$newest" "$KEYS" && chmod 600 "$KEYS"
  say "Copied OAuth client to $KEYS - you can delete the copy in Downloads"
fi

# ---------------------------------------------------------------- 3. install pinned MCP server
say "Installing $PKG@$PKG_VERSION from the official registry"
npm install -g "$PKG@$PKG_VERSION" --registry="$REGISTRY"
BIN="$(npm prefix -g)/bin/gmail-mcp"
[[ -x "$BIN" ]] || die "gmail-mcp binary not found at $BIN"

# ---------------------------------------------------------------- 4. register with Claude Code
say "Registering MCP server 'gmail' (user scope)"
claude mcp remove gmail -s user >/dev/null 2>&1 || true
claude mcp add gmail -s user -- "$BIN"

# ---------------------------------------------------------------- 5. OAuth consent
say "Starting OAuth - a Google sign-in page will open"
echo "Expect 'Google hasn't verified this app' -> Continue (it's your own app)."
(cd "$CONF_DIR" && "$BIN" auth)
chmod 600 "$CONF_DIR"/*.json

say "Checking connection"
claude mcp list | grep gmail
cat <<'EOF'

Done. Start a NEW Claude Code session and try: "show my 10 latest emails".
While the OAuth app is in "Testing", the token expires after ~7 days;
re-run ./reauth.sh, or publish the app on the Audience page to stop that.
EOF
