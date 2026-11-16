# claude-gmail-mcp

**Connect Gmail to Claude Code when the official connector is blocked by your organization.**
Uses your own Google Cloud OAuth client and a local MCP server, so it doesn't depend on anyone else's approval.

```
Claude Code ──stdio──▶ gmail-mcp (local, pinned v1.1.11) ──OAuth──▶ Gmail API
                                │
                                └── ~/.gmail-mcp/  (client keys + refresh token, chmod 600)
```

## Why this exists

On claude.ai the Gmail connector page showed *"Ask your organization owner to add this for your team."*
My Claude account belongs to an organization, and the admin hadn't enabled Gmail, so the one-click route was closed.
MCP is an open protocol, though, so Claude Code can talk to any MCP server running on my own machine.
I set this up end to end in about 15 minutes, then turned the manual steps into a script.

## Quick start

Prerequisites: `node`, `gcloud` (logged in), `claude` (Claude Code CLI).

```bash
git clone https://github.com/xungirl/claude-gmail-mcp.git
cd claude-gmail-mcp
./setup.sh            # or ./setup.sh <existing-gcp-project-id>
```

The script:

| Step | What happens | Automated? |
|---|---|---|
| 1 | Create a GCP project (**no billing account**, the Gmail API is free) and enable `gmail.googleapis.com` | ✅ gcloud |
| 2 | Configure the OAuth consent screen, add yourself as test user, create a **Desktop app** client, download the JSON | ❌ console only, the script opens the page and waits for the file in `~/Downloads` |
| 3 | Validate the JSON is a Desktop client, copy it to `~/.gmail-mcp/` with `chmod 600` | ✅ |
| 4 | `npm install -g` the MCP server **at a pinned version** from the official registry | ✅ |
| 5 | `claude mcp add gmail -s user` so every project sees it | ✅ |
| 6 | Run the OAuth flow (local callback on `localhost:3000`) | ✅ you click through Google sign-in |

Then open a **new** Claude Code session and ask *"show my 10 latest emails"*.
MCP servers load when a session starts, so the session you ran setup from won't see the new tools.

## Things that went wrong (and the fixes)

I'm keeping these here because they're the part a tutorial usually skips.

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | Gmail connector on claude.ai: *"contact your organization owner"* | Connectors are governed per organization | Skip claude.ai entirely and run a local MCP server with my own OAuth client |
| 2 | `npx … auth` hung silently, no browser, no output | `~/.npmrc` pointed to `registry.npm.taobao.org`, a **retired** mirror domain. The npm debug log showed endless `packumentCache … cache-miss` against it | Found it in `~/.npm/_logs`, installed with `--registry=https://registry.npmjs.org`, then reset the registry globally. The script always passes the official registry |
| 3 | Re-running `npx` on every Claude Code start = slow and network-dependent | `npx -y pkg` resolves the package every launch | Install once globally and point Claude Code at the absolute binary path |
| 4 | Console asks *"Use this client for AI-powered agents?"* | New Google option, not needed for a plain Desktop OAuth flow | Leave it **unchecked** |
| 5 | Token stops working after ~a week | OAuth apps in **Testing** status issue refresh tokens that expire in 7 days | `./reauth.sh`, or click *Publish app* on the Audience page (you'll see an "unverified app" warning, which is fine for a personal app) |

## Security choices

- **Pinned version.** This server gets the `gmail.modify` scope (read, label, draft, send, delete).
  `npx -y pkg` without a version would silently run whatever is published next, which is a supply-chain risk. Upgrades should be deliberate.
- **Your own OAuth client.** No third-party backend sees your tokens. They live only in `~/.gmail-mcp/` (`chmod 700` dir, `600` files).
- **`.gitignore` blocks `*.json`**, so client secrets and tokens can't be committed by accident.
- **Human in the loop.** I tell Claude Code to ask before sending or deleting anything. Drafts are the default.

## What I use it for

- Triage the inbox: a table of the latest emails with sender, subject and a one-line summary, with anything that needs action flagged (e.g. a bank payee change I didn't make)
- Pull internship OA / interview / rejection emails and sync them into my job-application tracker
- Draft replies that I review and send myself

## Verified

- macOS 15, Node 25, Claude Code CLI, `@gongrzhe/server-gmail-autoauth-mcp@1.1.11`, 2026-11-16
- After setup, `claude mcp list` shows `gmail: … ✔ Connected`, and a fresh session listed and summarized my latest 10 emails
- `setup.sh` is the manual run, turned into a script, and passes `shellcheck`

## Credits

MCP server: [GongRzhe/Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server) (MIT). This repo only contains the setup automation and notes.

---

### 中文速记

claude.ai 的 Gmail 连接器被组织管理员禁用了，所以改走「自己的 GCP OAuth 客户端 + 本地 MCP server」，不依赖任何人审批。踩到的坑有三个：npm 指向已停用的淘宝老镜像，导致 npx 卡死；Testing 模式下 token 7 天过期；建客户端时那个「AI 智能体」选项不要勾。安全方面：锁定包版本，凭证只存在本机并设 600 权限，`*.json` 全部 gitignore。运行 `./setup.sh` 一键复现。
