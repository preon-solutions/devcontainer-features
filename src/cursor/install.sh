#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "cursor: install.sh must run as root." >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
case "$ID" in
    debian|ubuntu) ;;
    *) echo "cursor: only Debian and Ubuntu are supported." >&2; exit 1 ;;
esac
case "$(dpkg --print-architecture)" in
    amd64|arm64) ;;
    *) echo "cursor: only AMD64 and ARM64 are supported." >&2; exit 1 ;;
esac

packages=(ca-certificates curl tar gzip libstdc++6 libgcc-s1 sudo)
missing=()
for package in "${packages[@]}"; do
    if [ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" != "install ok installed" ]; then
        missing+=("$package")
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
fi

feature_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d /usr/local/share/cursor-feature /usr/local/bin
# Prepare the mountpoint; runtime ownership is set after the volume is mounted.
install -d -m 0755 /var/lib/cursor
install -m 0755 "$feature_dir/oncreate.sh" /usr/local/share/cursor-feature/oncreate.sh

wrapper="$(mktemp)"
trap 'rm -f "$wrapper"' EXIT
cat > "$wrapper" <<'EOF'
#!/bin/sh
export CURSOR_CONFIG_DIR="${CURSOR_CONFIG_DIR:-/var/lib/cursor/config}"
export AGENT_CLI_CREDENTIAL_STORE=file
command="${0##*/}"
exec "$HOME/.local/bin/$command" "$@"
EOF
for command in agent cursor-agent; do
    install -m 0755 "$wrapper" "/usr/local/bin/$command"
done

echo "cursor: dependencies prepared; the official installer runs on container creation."
