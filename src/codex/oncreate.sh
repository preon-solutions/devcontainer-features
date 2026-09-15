#!/bin/bash
set -euo pipefail
umask 077

export CODEX_HOME=/var/lib/codex
export CODEX_INSTALL_DIR="$HOME/.local/bin"
export CODEX_NON_INTERACTIVE=1
export PATH="$HOME/.local/bin:$PATH"

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
        backup="$(mktemp -d "${path}.before-codex-feature.XXXXXX")"
        mv -- "$path" "$backup/original"
        echo "codex: preserved $path at $backup/original (not imported)."
    fi
    ln -s -- "$destination" "$path"
}

# Volumes are mounted only at runtime and initially belong to root.
as_root mkdir -p "$CODEX_HOME"
as_root chmod 0700 "$CODEX_HOME"
as_root chown -R --no-dereference "$(id -u):$(id -g)" "$CODEX_HOME"
link_dir "$HOME/.codex" "$CODEX_HOME"
mkdir -p "$CODEX_INSTALL_DIR"

# Existing volume configuration is preserved. The PATH wrapper also selects
# file credentials when an older shared config requests an OS keyring.
if [ ! -e "$CODEX_HOME/config.toml" ]; then
    printf 'cli_auth_credentials_store = "file"\n' > "$CODEX_HOME/config.toml"
fi

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer"
sh "$installer"
test -x "$CODEX_INSTALL_DIR/codex"
/usr/local/bin/codex --version
