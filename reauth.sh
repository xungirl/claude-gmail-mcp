#!/usr/bin/env bash
# Re-run the Gmail OAuth consent (e.g. after the 7-day Testing-mode expiry).
set -euo pipefail
cd "$HOME/.gmail-mcp"
"$(npm prefix -g)/bin/gmail-mcp" auth
chmod 600 "$HOME"/.gmail-mcp/*.json
claude mcp list | grep gmail
