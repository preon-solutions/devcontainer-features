#!/bin/bash
set -euo pipefail
umask 077

cursor_home=/var/lib/cursor
export CURSOR_CONFIG_DIR="$cursor_home/config"
export AGENT_CLI_CREDENTIAL_STORE=file
export PATH="$HOME/.local/bin:$PATH"
auth_dir="$cursor_home/auth"

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

link_dir() {
    local path="$1" destination="$2" backup
    mkdir -p "$(dirname "$path")"
    if [ -L "$path" ] && [ "$(readlink "$path")" = "$destination" ]; then
        return
    fi
    if [ -e "$path" ] || [ -L "$path" ]; then
        backup="$(mktemp -d "${path}.before-cursor-feature.XXXXXX")"
        mv -- "$path" "$backup/original"
        echo "cursor: preserved $path at $backup/original (not imported)."
    fi
    ln -s -- "$destination" "$path"
}

as_root mkdir -p "$CURSOR_CONFIG_DIR" "$auth_dir"
as_root chmod 0700 "$cursor_home" "$CURSOR_CONFIG_DIR" "$auth_dir"
as_root chown -R --no-dereference "$(id -u):$(id -g)" "$cursor_home"
link_dir "$HOME/.cursor" "$CURSOR_CONFIG_DIR"
link_dir "${XDG_CONFIG_HOME:-$HOME/.config}/cursor" "$auth_dir"
# Also wire the conventional path if this container sets XDG_CONFIG_HOME.
if [ "${XDG_CONFIG_HOME:-$HOME/.config}" != "$HOME/.config" ]; then
    link_dir "$HOME/.config/cursor" "$auth_dir"
fi
mkdir -p "$HOME/.local/bin"

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL https://cursor.com/install -o "$installer"
bash -e -o pipefail "$installer"
test -x "$HOME/.local/bin/agent"
test -x "$HOME/.local/bin/cursor-agent"
/usr/local/bin/agent --version
/usr/local/bin/cursor-agent --version
