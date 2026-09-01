# Security

This document describes the **IronWallet Setup** binary (`ironwallet-setup`).
Installer **source is not published** — only signed binaries. This file does
not describe the runtime behavior of `@ironwallet/mcp-server` beyond the
command line the installer writes.

The installer does not copy itself into Program Files / Applications, does not
create its own data directory, does not register a product in “Apps &
features”, and does not start a background process.

## Privileges

The binary does not request administrator rights. User-profile JSON is written
without elevation.

Elevation can still appear from **other** tools this process may spawn:

| Step | When | How |
|------|------|-----|
| Node.js | Node 20+ is not on PATH | Windows: `winget install -e --id OpenJS.NodeJS.LTS` (MSI may UAC). macOS: `brew install node`. Linux: `apt-get` or `dnf` install `nodejs` `npm`, wrapped in `pkexec` when `pkexec` exists. |
| Git | Claude Code is selected and `git` is missing | Windows: `winget install -e --id Git.Git`. macOS: `brew install git`. Linux: `apt-get install -y git` via `pkexec` when present. |

There is no silent / GPO install path.

## Persistent OS state this binary does not write

- Run / login items, LaunchAgents, systemd units, Windows services
- Windows registry **values** (it only **reads**
  `HKCR\<scheme>\shell\open\command` for `cursor`, `claude`, and `vscode` to
  decide whether a deeplink would hit a CLI shim)
- The installer itself in PATH or in the list of installed programs

The installer only prepends already-existing directories onto **this
process’s** `PATH`. It does not edit the user or machine PATH. If winget,
Homebrew, or the distro installer change PATH, that is those tools, not this
binary.

## Files and directories

The only directories the installer creates are parents of `mcp.json`
(mode `0755`).

### Windows

| Path | Action |
|------|--------|
| `%USERPROFILE%\.cursor\mcp.json` | Create or merge. Only key `ironwallet`. |
| `%APPDATA%\Code\User\mcp.json` | Create or merge. Only key `ironwallet`. If `APPDATA` is empty: `%USERPROFILE%\AppData\Roaming\Code\User\mcp.json`. |
| `%APPDATA%\Claude\claude_desktop_config.json` | Only when a classic (non-Store) Claude Desktop install is found. Create or merge. Only key `ironwallet`. |
| `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\claude_desktop_config.json` | Only when the Store (MSIX) Claude Desktop is found — that build reads this containerized path, not `%APPDATA%`. Create or merge. Only key `ironwallet`. |

### macOS

| Path | Action |
|------|--------|
| `~/.cursor/mcp.json` | Create or merge. Only key `ironwallet`. |
| `~/Library/Application Support/Code/User/mcp.json` | Create or merge. Only key `ironwallet`. |
| `~/Library/Application Support/Claude/claude_desktop_config.json` | Only when `/Applications/Claude.app` exists. Create or merge. Only key `ironwallet`. |

### Linux

| Path | Action |
|------|--------|
| `~/.cursor/mcp.json` | Create or merge. Only key `ironwallet`. |
| `$XDG_CONFIG_HOME/Code/User/mcp.json` or `~/.config/Code/User/mcp.json` | Create or merge. Only key `ironwallet`. |

**Other MCP servers in those files are left in place.** A missing or empty
file becomes a new JSON object that contains only `ironwallet`. Invalid JSON
is an error; the file is not replaced with `{}`.

Claude Desktop’s `claude_desktop_config.json` is written **only** when the
desktop app itself is detected (paths above). Because a GUI app does not
inherit the shell PATH, that entry uses an absolute path to `npx` — on
Windows wrapped as `cmd /c <npx.cmd>`. If `npx` is not on the installer’s
PATH the write is skipped with a log line; it never blocks the Claude Code
CLI flow. On Linux there is no Claude Desktop, so nothing is written.

### Written by CLIs this installer may run (not edited here)

| Environment | Commands | Typical side effect |
|-------------|----------|---------------------|
| Claude Code | `npm install -g @anthropic-ai/claude-code` if `claude` is missing (uses `--prefix ~/.local` when the npm global root is not writable); `claude plugin marketplace add ironwallet/ironwallet-agent-kit`; `claude plugin install ironwallet-mcp@ironwallet --scope user` (retry without `--scope` if the flag is unknown) | Marketplace/plugin under `~/.claude`; CLI may land in `~/.local` |
| Codex | `codex plugin marketplace add …`; `codex plugin add ironwallet-mcp@ironwallet` — via `codex` on PATH, or the CLI bundled with the ChatGPT desktop app (Windows: `%LOCALAPPDATA%\OpenAI\Codex\bin`, then `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`, then the npm shim; macOS: `~/.local/bin/codex` or the app bundle) | `~/.codex` |
| Grok | `grok plugin marketplace add …`; `grok plugin install ironwallet-mcp --trust` | `~/.grok` |

`--trust` is passed to Grok as shown. Errors whose text contains `already`,
`exists`, or `duplicate` are treated as success.

## Process impact during install

Before writing configs, the installer asks selected GUI apps to quit and waits
800 ms. It does not force-kill.

- Windows: `WM_CLOSE` to visible windows of `cursor.exe`, `claude.exe`,
  `code.exe`. WinGet Links, npm shims, and `\.local\bin\` images are skipped.
- macOS: `osascript` `quit app "Cursor"` / `"Claude"` / `"Visual Studio Code"`.
- Linux: `pkill -TERM -x cursor` / `code`. Claude has no Linux process name so
  the CLI is not signalled.

## Network and third-party downloads

This binary has no HTTP client of its own except opening a URL in the default
browser.

### Node.js

| OS | Source | Integrity check by the installer |
|----|--------|----------------------------------|
| Windows | winget package `OpenJS.NodeJS.LTS` | None. Trust winget. |
| macOS | Homebrew formula `node` | None. Trust Homebrew. |
| Linux | distro `nodejs` + `npm` | None. Trust the distro. |
| Fallback | browser to `https://nodejs.org/en/download` | User-installed. Retry only re-reads PATH and `node -v`. |

There is no `curl | sh`.

### Other hosts touched during a successful install

- **winget / Homebrew / apt / dnf** — Node.js; Git only if Claude is selected
  and `git` is missing.
- **npm** — `npx -y --package=@ironwallet/mcp-server -- node -e process.exit(0)`
  once per install to populate the npx cache (does not start the MCP server).
  Also `npm install -g @anthropic-ai/claude-code` only if Claude is selected
  and `claude` is not on PATH.
- **GitHub** — `claude` / `codex` / `grok plugin marketplace add
  ironwallet/ironwallet-agent-kit` (those CLIs fetch
  `github.com/ironwallet/ironwallet-agent-kit`).
- **Browser (user click)** — official download pages for Cursor, VS Code,
  Claude Code, Codex, Grok, Node.js.

### After the installer exits

`ironwallet-setup` does not call home, check for updates, or keep a service.

The next hop after exit is usually a cache hit: agents run the same
`npx -y @ironwallet/mcp-server` command. A later download still happens if
the npx cache was cleared or the package spec changes. What the running
server sends is out of scope for this file.

No proxy, MITM, or `HTTP_PROXY` handling is implemented here. Child tools use
the ambient environment. Closed networks that block GitHub or npm will fail
plugin install and the npx prefetch.

## First-run prompt

Prefill used only when the user clicks Open or Finish on the done screen:

```
Using the IronWallet MCP tools, show what you can do: list my wallets and balances, and briefly explain how transfers, swaps, and deposit QR codes work from this chat.
```

It is not stored in MCP JSON. It does not mention a seed, recovery phrase,
private key, or mnemonic.

## Removal

There is no uninstall entry point. Manual steps and leftovers are in
[README.md](README.md#uninstall). In particular, Node.js and Git are **not**
rolled back even if this session installed them; the installer does not
remember that it did.

## Reporting

Report issues on the public installer GitHub Releases / issues (binaries and
these docs only) or via [ironwallet.io/ai](https://ironwallet.io/ai). Do not
paste recovery phrases or private keys into tickets.
