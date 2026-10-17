# nolo-apps

**A keyboard-driven macOS terminal manager for installing, removing, and auditing Antigravity IDE and CLI.**

Zero dependencies. One Bash file. Live status, dry-run mode, confirmed deletes, and scriptable flags.

![platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![shell](https://img.shields.io/badge/shell-bash%203.2%2B-blue)
![dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## Why

Installing and fully removing a macOS app plus its CLI usually means hunting through `/Applications`, `~/Library`, hidden dotfiles, and `~/.zshrc`. `nolo-apps` does that search for you, shows exactly what it found, and removes only what you confirm.

## Features

- **Interactive TUI.** Arrow keys, number keys `1`–`6`, or `q` to quit.
- **Live status header.** Shows CPU architecture, where the CLI and IDE are installed, and how many residual items remain.
- **Install** the Antigravity CLI, the Intel IDE, or both, with a progress bar.
- **Deep uninstall.** Removes the app, CLI binaries, dotfiles, `~/Library` leftovers, and Antigravity PATH/alias lines in `~/.zshrc`.
- **Read-only scan.** Lists every residual path with its type and size. Changes nothing.
- **Dry run.** Prints every command it would run and executes none of them.
- **Scriptable.** Every action has a flag for use in shell scripts and automation.
- **Safe by default.** Deletes are listed and confirmed first. `~/.zshrc` is backed up before it changes.

## Requirements

- macOS (tested on Darwin 25.x)
- Bash 3.2 or newer (the default macOS shell works)
- `curl`, `hdiutil`, `xattr`, `sudo`: all present on a stock Mac

Nothing to install. Nothing to `pip install` or `brew install`.

## Quick start

```bash
git clone https://github.com/festomanolo/nolo-apps.git
cd nolo-apps
chmod +x nolo-apps
./nolo-apps
```

Optional: put it on your `PATH` for use from anywhere:

```bash
mkdir -p ~/.local/bin
cp nolo-apps ~/.local/bin/nolo-apps
```

If `~/.local/bin` is not on your `PATH`, add this line to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Interactive menu

```
  ⚡ NOLO-APPS v2.0.0 — macOS App & Residual Manager
  ─────────────────────────────────────────────────────────────
  Arch       : arm64
  CLI        : ● INSTALLED /Users/you/.local/bin/agy
  IDE        : ○ NOT FOUND
  Residuals  : 0 (clean)

  ❯ [1] 🚀 Install Everything     (CLI + Intel IDE)
     [2] ⚡ Install CLI Only       (official install script)
     [3] 💻 Install IDE Only       (Intel DMG)
     [4] 🧹 Deep Uninstall All     (IDE + CLI + residuals + ~/.zshrc)
     [5] 🔍 Scan Residuals         (read-only)
     [6] ❌ Exit nolo-apps
```

| Key | Action |
| --- | --- |
| `↑` / `↓` | Move the selection |
| `1`–`6` | Run that item immediately |
| `Enter` | Run the selected item |
| `d` | Toggle dry-run mode (shown as `[DRY-RUN]` in the header) |
| `q` | Quit |

### Command-line flags

| Flag | Effect |
| --- | --- |
| `--install-all` | Install the CLI, then the IDE |
| `--install-cli` | Install the CLI only |
| `--install-ide` | Install the IDE only (Intel build) |
| `--uninstall` | Deep uninstall, with confirmation |
| `--scan` | Scan for residuals; changes nothing |
| `--dry-run` | Print commands without running them. Combine with any action. |
| `-y`, `--yes` | Skip confirmation prompts |
| `-h`, `--help` | Show help |
| `--version` | Print the version |

Examples:

```bash
# Preview a full removal before doing it
./nolo-apps --dry-run --uninstall

# Audit a machine in CI or a setup script
./nolo-apps --scan

# Unattended reinstall
./nolo-apps --install-ide -y
```

## What gets removed

`--uninstall` shows this list before it does anything:

| Type | Paths |
| --- | --- |
| `APP` | `/Applications/Antigravity IDE.app`, `/Applications/Antigravity.app`, `~/Applications/Antigravity IDE.app` |
| `BINARY` | `~/.local/bin/agy`, `~/.local/bin/agy-ide`, `~/.local/bin/antigravity-ide` |
| `DOTFILE` | `~/.antigravity`, `~/.antigravity-ide`, `~/.antigravity_tools`, `~/.gemini/antigravity`, `~/.gemini/antigravity-cli` |
| `LIBRARY` | Any `*antigravity*` entry within three levels of `~/Library` |
| `ZSHRC` | Lines in `~/.zshrc` that set `PATH` or an `agy` alias and mention Antigravity or `agy` |

Before editing `~/.zshrc`, the script copies it to `~/.zshrc.nolo-bak`.

## Safety model

1. **Preview first.** Scan and dry-run show what would change without changing it.
2. **Confirm before delete.** Uninstall lists every target and waits for `y`.
3. **Narrow matches.** Shell-config edits are limited to Antigravity PATH and alias lines. Process kills match the exact app bundle path or the `agy` binary name.
4. **Backups.** `~/.zshrc` is copied to `~/.zshrc.nolo-bak` before any edit.
5. **Verified installers.** The CLI installer is downloaded to a temp file before it runs, so a failed download never executes partial code. The IDE image must contain `Antigravity IDE.app`, or the install stops.
6. **Clean failures.** Temp directories and mounted disk images are removed on error.

## How it works

- **Detection** uses `[ -d ]`, `[ -x ]`, and `command -v`. Nothing is cached.
- **IDE install** downloads the DMG to a temp directory, mounts it read-only at a temp mount point, copies the app to `/Applications`, clears `com.apple.quarantine` so Gatekeeper does not block launch, then detaches the image.
- **Uninstall** stops the app by bundle path, removes the list from the scan, and cleans `~/.zshrc`. It re-scans at the end and reports anything left.

## Configuration

Edit the variables at the top of `nolo-apps`:

| Variable | Purpose |
| --- | --- |
| `DMG_URL` | IDE disk image URL (currently Antigravity 2.5.5, `darwin-x64`) |
| `CLI_URL` | CLI install script URL |
| `IDE_APP` | Application bundle name |
| `ZSH_PATTERN` | Regex for `~/.zshrc` lines to remove |

The IDE URL is pinned to a version. If it stops working, update `DMG_URL` to the current release.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Intel build on Apple Silicon` warning | The IDE runs under Rosetta 2. Install it with `softwareupdate --install-rosetta --agree-to-license`. |
| `sudo authentication failed` | Run from a real terminal. `sudo` needs a TTY for the password prompt. |
| `Could not download` | Check the network, then confirm `DMG_URL` or `CLI_URL` is current. |
| Scan lists something you want to keep | Remove it by hand, or edit the scan lists in the script. The uninstall prompt always shows the list first. |
| 