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

- **Interactive TUI.** Arr