#!/usr/bin/env bash
# ==============================================================================
# nolo-apps — macOS Antigravity install / uninstall / residual manager
# ==============================================================================
# Interactive TUI by default. Scriptable via flags (see --help).
# Destructive steps are listed and confirmed first; --dry-run prints every
# command without executing it.
# ==============================================================================

VERSION="2.0.0"
DMG_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/darwin-x64/Antigravity%20IDE.dmg"
CLI_URL="https://antigravity.google/cli/install.sh"
IDE_APP="Antigravity IDE.app"
ZSH_PATTERN='^[[:space:]]*(export[[:space:]]+PATH=|alias[[:space:]]+agy=).*(antigravity|agy)'

# Cursor machine-ID storage paths (macOS)
CURSOR_STORAGE="$HOME/Library/Application Support/Cursor/User/globalStorage/storage.json"
CURSOR_SQLITE="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
CURSOR_MACHINE_ID_FILE="$HOME/Library/Application Support/Cursor/machineId"

DRY_RUN=0
ASSUME_YES=0
_RESET_DONE=0   # prevents double-reset when install-all runs both functions

# ANSI styling
BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
CYAN="\033[38;5;51m"; PURPLE="\033[38;5;141m"; GREEN="\033[38;5;48m"
RED="\033[38;5;196m"; YELLOW="\033[38;5;220m"; GRAY="\033[38;5;242m"
WHITE="\033[38;5;255m"; BG_SELECT="\033[48;5;236m"

hide_cursor() { printf "\033[?25l"; }
show_cursor() { printf "\033[?25h"; }
trap 'show_cursor; echo; exit 130' INT TERM
trap 'show_cursor' EXIT

# ------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------
log()     { printf "  %b\n" "$*"; }
ok()      { printf "  ${GREEN}+ %s${RESET}\n" "$*"; }
warn()    { printf "  ${YELLOW}! %s${RESET}\n" "$*"; }
err()     { printf "  ${RED}x %s${RESET}\n" "$*" >&2; }
section() { printf "\n  ${CYAN}${BOLD}>> %s${RESET}\n\n" "$*"; }

# Run a command, or only print it in dry-run mode.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "  ${DIM}[dry-run] %s${RESET}\n" "$*"
        return 0
    fi
    "$@"
}

# Yes/no prompt. -y skips it.
confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    local ans
    printf "  ${YELLOW}%s [y/N] ${RESET}" "$1"
    IFS= read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# progress_bar <current> <total> <label>
progress_bar() {
    local current=$1 total=$2 label=$3 width=32
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar="" i
    for ((i = 0; i < filled; i++)); do bar+="#"; done
    for ((i = 0; i < empty; i++)); do bar+="-"; done
    printf "\r  ${PURPLE}[${CYAN}%s${PURPLE}]${RESET} ${BOLD}%3d%%${RESET} %-44s" \
        "$bar" $(( current * 100 / total )) "$label"
    [ "$current" -eq "$total" ] && echo
    return 0
}

# ------------------------------------------------------------------------------
# Detection
# ------------------------------------------------------------------------------
cli_path() {
    if [ -x "$HOME/.local/bin/agy" ]; then
        echo "$HOME/.local/bin/agy"
    else
        command -v agy 2>/dev/null
    fi
}

ide_path() {
    local p
    for p in "/Applications/$IDE_APP" "/Applications/Antigravity.app" "$HOME/Applications/$IDE_APP"; do
        if [ -d "$p" ]; then echo "$p"; return 0; fi
    done
    return 1
}

bin_targets() {
    printf '%s\n' "$HOME/.local/bin/agy" "$HOME/.local/bin/agy-ide" "$HOME/.local/bin/antigravity-ide"
}

dotfile_targets() {
    printf '%s\n' "$HOME/.antigravity" "$HOME/.antigravity-ide" "$HOME/.antigravity_tools" \
        "$HOME/.gemini/antigravity-cli" "$HOME/.gemini/antigravity"
}

library_matches() {
    find "$HOME/Library" -maxdepth 3 -iname "*antigravity*" 2>/dev/null
}

zshrc_hits() {
    [ -f "$HOME/.zshrc" ] && grep -Eq "$ZSH_PATTERN" "$HOME/.zshrc"
}

# Every existing residual path, one per line.
found_items() {
    {
        ide_path
        bin_targets
        dotfile_targets
        library_matches
    } | while IFS= read -r p; do
        [ -n "$p" ] && [ -e "$p" ] && echo "$p"
    done | sort -u
}

kind_of() {
    case "$1" in
        /Applications/*|"$HOME"/Applications/*) echo "APP" ;;
        */.local/bin/*)                         echo "BINARY" ;;
        "$HOME"/Library/*)                      echo "LIBRARY" ;;
        *)                                      echo "DOTFILE" ;;
    esac
}

# ------------------------------------------------------------------------------
# Header
# ------------------------------------------------------------------------------
draw_header() {
    clear
    local cli ide count badge=""
    if [ -n "$(cli_path)" ]; then cli="${GREEN}* INSTALLED${RESET} ${DIM}$(cli_path)${RESET}"
    else cli="${GRAY}- NOT FOUND${RESET}"; fi
    if ide_path >/dev/null; then ide="${GREEN}* INSTALLED${RESET} ${DIM}$(ide_path)${RESET}"
    else ide="${GRAY}- NOT FOUND${RESET}"; fi
    count=$(found_items | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then count="${YELLOW}${count} item(s)${RESET}"
    else count="${GREEN}0 (clean)${RESET}"; fi
    [ "$DRY_RUN" -eq 1 ] && badge="  ${YELLOW}[DRY-RUN]${RESET}"

    printf "\n  ${BOLD}${CYAN}NOLO-APPS${RESET} ${DIM}v%s${RESET} — macOS App & Residual Manager%b\n" "$VERSION" "$badge"
    printf "  ${PURPLE}-------------------------------------------------------------${RESET}\n"
    printf "  Arch       : %s\n" "$(uname -m)"
    printf "  CLI        : %b\n" "$cli"
    printf "  IDE        : %b\n" "$ide"
    printf "  Residuals  : %b\n\n" "$count"
}

pause_return() {
    echo
    printf "  ${DIM}Press any key to return to the menu...${RESET}"
    show_cursor
    IFS= read -rsn1 _
    echo
}

# ------------------------------------------------------------------------------
# Reset Cursor machine ID (runs automatically before installs)
# Mirrors the logic from cursor-free-vip reset_machine_manual.py.
# Generates fresh UUIDs / SHA hashes and writes them to Cursor's storage.
# ------------------------------------------------------------------------------
reset_machine_id() {
    section "Resetting Cursor Machine ID"
    _RESET_DONE=1

    # Generate fresh IDs using Python (available on every macOS)
    local dev_device_id machine_id mac_machine_id sqm_id
    dev_device_id=$(python3 -c "import uuid; print(uuid.uuid4())")
    machine_id=$(python3 -c "import hashlib,os; print(hashlib.sha256(os.urandom(32)).hexdigest())")
    mac_machine_id=$(python3 -c "import hashlib,os; print(hashlib.sha512(os.urandom(64)).hexdigest())")
    sqm_id=$(python3 -c "import uuid; print('{' + str(uuid.uuid4()).upper() + '}')")

    # ---- machineId flat file ------------------------------------------------
    local mid_dir
    mid_dir=$(dirname "$CURSOR_MACHINE_ID_FILE")
    if [ ! -d "$mid_dir" ]; then
        mkdir -p "$mid_dir"
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log "${DIM}[dry-run] write $dev_device_id -> $CURSOR_MACHINE_ID_FILE${RESET}"
    else
        if [ -f "$CURSOR_MACHINE_ID_FILE" ]; then
            cp "$CURSOR_MACHINE_ID_FILE" "${CURSOR_MACHINE_ID_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        printf '%s' "$dev_device_id" > "$CURSOR_MACHINE_ID_FILE"
        ok "machineId file updated."
    fi

    # ---- storage.json -------------------------------------------------------
    if [ -f "$CURSOR_STORAGE" ]; then
        if [ "$DRY_RUN" -eq 0 ]; then
            cp "$CURSOR_STORAGE" "${CURSOR_STORAGE}.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            log "${DIM}[dry-run] patch $CURSOR_STORAGE with new IDs${RESET}"
        else
            python3 - "$CURSOR_STORAGE" "$dev_device_id" "$machine_id" "$mac_machine_id" "$sqm_id" <<'PYEOF'
import sys, json
path, dev_id, mid, mmid, sqm = sys.argv[1:]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
data.update({
    "telemetry.devDeviceId": dev_id,
    "telemetry.macMachineId": mmid,
    "telemetry.machineId": mid,
    "telemetry.sqmId": sqm,
    "storage.serviceMachineId": dev_id,
})
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
PYEOF
            ok "storage.json patched."
        fi
    else
        warn "storage.json not found — Cursor may not be installed yet. Skipping JSON patch."
    fi

    # ---- SQLite state.vscdb -------------------------------------------------
    if [ -f "$CURSOR_SQLITE" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log "${DIM}[dry-run] update $CURSOR_SQLITE with new IDs${RESET}"
        else
            python3 - "$CURSOR_SQLITE" "$dev_device_id" "$machine_id" "$mac_machine_id" "$sqm_id" <<'PYEOF'
import sys, sqlite3
path, dev_id, mid, mmid, sqm = sys.argv[1:]
con = sqlite3.connect(path)
cur = con.cursor()
cur.execute("CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value TEXT)")
for k, v in [
    ("telemetry.devDeviceId", dev_id),
    ("telemetry.macMachineId", mmid),
    ("telemetry.machineId", mid),
    ("telemetry.sqmId", sqm),
    ("storage.serviceMachineId", dev_id),
]:
    cur.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)", (k, v))
con.commit()
con.close()
PYEOF
            ok "SQLite database updated."
        fi
    else
        warn "state.vscdb not found — Cursor may not be installed yet. Skipping SQLite patch."
    fi

    [ "$DRY_RUN" -eq 0 ] && printf "\n  ${CYAN}New IDs:${RESET}\n" \
        && printf "  devDeviceId  : ${GREEN}%s${RESET}\n" "$dev_device_id" \
        && printf "  machineId    : ${GREEN}%s${RESET}\n" "$machine_id" \
        && printf "  macMachineId : ${GREEN}%s${RESET}\n" "$mac_machine_id" \
        && printf "  sqmId        : ${GREEN}%s${RESET}\n" "$sqm_id"
    return 0
}

# ------------------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------------------
install_cli() {
    [ "$_RESET_DONE" -eq 0 ] && reset_machine_id && echo
    section "Installing Antigravity CLI"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "${DIM}[dry-run] download $CLI_URL, then run it${RESET}"
        return 0
    fi
    # Download first, then execute: a failed download never runs partial code.
    local tmp
    tmp=$(mktemp -t nolo-agy) || return 1
    if ! curl -fsSL "$CLI_URL" -o "$tmp"; then
        err "Could not download the CLI installer."
        rm -f "$tmp"; return 1
    fi
    bash "$tmp"; local rc=$?
    rm -f "$tmp"
    if [ "$rc" -eq 0 ]; then ok "Antigravity CLI installed."; else err "CLI installer exited with $rc."; return 1; fi
}

install_ide() {
    [ "$_RESET_DONE" -eq 0 ] && reset_machine_id && echo
    section "Installing Antigravity IDE (Intel x64)"
    if [ "$(uname -m)" = "arm64" ]; then
        warn "Intel build on Apple Silicon: runs under Rosetta 2 (softwareupdate --install-rosetta --agree-to-license)."
    fi
    if ide_path >/dev/null; then
        confirm "Antigravity IDE is already installed. Replace it?" || { warn "Skipped."; return 1; }
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log "${DIM}[dry-run] download DMG -> mount -> copy '$IDE_APP' to /Applications -> strip quarantine -> detach${RESET}"
        return 0
    fi

    sudo -v || { err "sudo authentication failed."; return 1; }

    local dir dmg mnt src rc=0
    dir=$(mktemp -d -t nolo-apps) || return 1
    dmg="$dir/antigravity.dmg"
    mnt="$dir/mnt"
    src="$mnt/$IDE_APP"
    mkdir "$mnt"

    log "${DIM}Source: Google Edge DL (v2.5.5)${RESET}"
    if ! curl -# -fL -o "$dmg" "$DMG_URL"; then
        err "Download failed."; rm -rf "$dir"; return 1
    fi

    progress_bar 1 4 "Mounting disk image..."
    if ! hdiutil attach "$dmg" -mountpoint "$mnt" -nobrowse -readonly -quiet; then
        err "Could not mount the disk image."; rm -rf "$dir"; return 1
    fi

    if [ ! -d "$src" ]; then
        err "'$IDE_APP' not found inside the disk image."
        hdiutil detach "$mnt" -quiet; rm -rf "$dir"; return 1
    fi

    progress_bar 2 4 "Copying to /Applications..."
    sudo rm -rf "/Applications/$IDE_APP" && sudo cp -R "$src" /Applications/ || rc=1

    progress_bar 3 4 "Clearing Gatekeeper quarantine..."
    [ "$rc" -eq 0 ] && sudo xattr -dr com.apple.quarantine "/Applications/$IDE_APP" 2>/dev/null

    progress_bar 4 4 "Detaching and cleaning up..."
    hdiutil detach "$mnt" -quiet 2>/dev/null
    rm -rf "$dir"

    if [ "$rc" -eq 0 ]; then ok "Antigravity IDE installed to /Applications."; else err "Copy failed."; return 1; fi
}

uninstall_all() {
    section "Deep uninstall: Antigravity IDE, CLI and residuals"
    local items total i=0 left
    items=$(found_items)

    if [ -z "$items" ] && ! zshrc_hits; then
        ok "Nothing to remove."
        return 0
    fi

    log "${BOLD}The following will be removed:${RESET}"
    printf '%s\n' "$items" | while IFS= read -r p; do
        [ -n "$p" ] && printf "    ${YELLOW}%-8s${RESET} %s\n" "$(kind_of "$p")" "$p"
    done
    zshrc_hits && printf "    ${YELLOW}%-8s${RESET} Antigravity/agy PATH & alias lines in ~/.zshrc (backup kept)\n" "ZSHRC"
    echo

    confirm "Proceed with deep uninstall?" || { warn "Cancelled. Nothing was removed."; return 1; }

    if [ "$DRY_RUN" -eq 0 ]; then
        sudo -v || { err "sudo authentication failed."; return 1; }
    fi

    section "Stopping processes"
    run pkill -f "/Applications/Antigravity IDE.app/" 2>/dev/null
    run pkill -f "/Applications/Antigravity.app/" 2>/dev/null
    run pkill -x agy 2>/dev/null
    [ "$DRY_RUN" -eq 0 ] && sleep 0.5

    total=$(printf '%s\n' "$items" | grep -c .)
    if [ "$total" -gt 0 ]; then
        section "Removing files"
        while IFS= read -r p; do
            [ -z "$p" ] && continue
            i=$((i + 1))
            progress_bar "$i" "$total" "Removing $(basename "$p")"
            case "$p" in
                /Applications/*) run sudo rm -rf "$p" ;;
                *)               run rm -rf "$p" ;;
            esac
        done <<< "$items"
    fi

    if zshrc_hits; then
        section "Cleaning ~/.zshrc"
        run cp "$HOME/.zshrc" "$HOME/.zshrc.nolo-bak"
        run sed -i '' -E "/$ZSH_PATTERN/d" "$HOME/.zshrc"
        ok "PATH/alias lines removed (backup: ~/.zshrc.nolo-bak)."
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        ok "Dry run complete. No changes made."
        return 0
    fi

    left=$(found_items | grep -c .)
    if [ "$left" -eq 0 ] && ! zshrc_hits; then
        ok "Deep uninstall finished. No Antigravity files or residuals remain."
    else
        warn "$left residual item(s) could not be removed. Run the scan for details."
        return 1
    fi
}

scan_residuals() {
    section "Scanning for Antigravity files and residuals"
    local found=0 p
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        printf "  ${YELLOW}%-8s${RESET} %s ${DIM}(%s)${RESET}\n" \
            "$(kind_of "$p")" "$p" "$(du -sh "$p" 2>/dev/null | cut -f1)"
        found=$((found + 1))
    done < <(found_items)

    if zshrc_hits; then
        printf "  ${YELLOW}%-8s${RESET} Antigravity/agy PATH or alias lines in ~/.zshrc\n" "ZSHRC"
        found=$((found + 1))
    fi

    if [ "$found" -eq 0 ]; then
        ok "Your Mac is clean. No Antigravity files or residuals found."
    else
        echo
        log "${DIM}$found item(s) found. Use 'Deep Uninstall' to remove them.${RESET}"
    fi
}

# ------------------------------------------------------------------------------
# Dispatch
# ------------------------------------------------------------------------------
dispatch() {
    case "$1" in
        all)       reset_machine_id; echo; install_cli; echo; install_ide ;;
        cli)       install_cli ;;
        ide)       install_ide ;;
        reset)     reset_machine_id ;;
        uninstall) uninstall_all ;;
        scan)      scan_residuals ;;
    esac
}

usage() {
    cat << EOF
nolo-apps v$VERSION: Antigravity install / uninstall / residual manager

Usage: nolo-apps [options] [action]

Actions (omit for interactive menu):
  --install-all         Install CLI and IDE (resets Cursor machine ID first)
  --install-cli         Install CLI only    (resets Cursor machine ID first)
  --install-ide         Install IDE only    (resets Cursor machine ID first)
  --reset-machine-id    Reset Cursor machine ID only (no install)
  --uninstall           Deep uninstall (IDE, CLI, residuals, ~/.zshrc lines)
  --scan                Scan for residuals, no changes

Options:
  --dry-run             Print what would run, change nothing
  -y, --yes             Skip confirmation prompts
  -h, --help            Show this help
  --version             Show version
EOF
}

# ------------------------------------------------------------------------------
# Interactive menu
# ------------------------------------------------------------------------------
OPTIONS=(
    "  Install Everything      CLI + Intel IDE"
    "  Install CLI Only        official install script"
    "  Install IDE Only        Intel DMG"
    "  Reset Cursor Machine ID standalone"
    "🧹 Deep Uninstall All     (IDE + CLI + residuals + ~/.zshrc)"
    "🔍 Scan Residuals         (read-only)"
    "❌ Exit nolo-apps"
)
ACTIONS=(all cli ide reset uninstall scan exit)

execute_selected() {
    show_cursor
    draw_header
    case "$1" in
        6) echo; ok "Exited nolo-apps."; exit 0 ;;
        *)
            dispatch "${ACTIONS[$1]}"
            pause_return
            ;;
    esac
}

menu_loop() {
    local selected=0 key rest n=${#OPTIONS[@]} i num
    while true; do
        hide_cursor
        draw_header
        printf "  ${DIM}↑/↓ or 1-7 select · Enter run · d toggle dry-run · q quit${RESET}\n\n"
        for i in "${!OPTIONS[@]}"; do
            num=$((i + 1))
            if [ "$i" -eq "$selected" ]; then
                printf "  ${BG_SELECT}${CYAN} ❯ [%s] ${BOLD}${WHITE}%s ${RESET}\n" "$num" "${OPTIONS[$i]}"
            else
                printf "     ${GRAY}[%s]${RESET} %s\n" "$num" "${OPTIONS[$i]}"
            fi
        done

        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 rest
            case "$rest" in
                "[A") selected=$(( (selected - 1 + n) % n )) ;;
                "[B") selected=$(( (selected + 1) % n )) ;;
            esac
            continue
        fi

        case "$key" in
            [1-7]) execute_selected $(( key - 1 )) ;;
            "")    execute_selected "$selected" ;;
            d|D)   DRY_RUN=$(( 1 - DRY_RUN )) ;;
            q|Q)   show_cursor; echo; ok "Goodbye!"; exit 0 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------
ACTION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)           DRY_RUN=1 ;;
        -y|--yes)            ASSUME_YES=1 ;;
        --install-all)       ACTION=all ;;
        --install-cli)       ACTION=cli ;;
        --install-ide)       ACTION=ide ;;
        --reset-machine-id)  ACTION=reset ;;
        --uninstall)         ACTION=uninstall ;;
        --scan)              ACTION=scan ;;
        -h|--help)           usage; exit 0 ;;
        --version)           echo "$VERSION"; exit 0 ;;
        *)                   err "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

if [ -n "$ACTION" ]; then
    dispatch "$ACTION"
    exit $?
fi

menu_loop
