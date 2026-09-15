#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "codex: install.sh must run as root." >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
case "$ID" in
    debian|ubuntu) ;;
    *) echo "codex: only Debian and Ubuntu are supported." >&2; exit 1 ;;
esac
case "$(dpkg --print-architecture)" in
    amd64|arm64) ;;
    *) echo "codex: only AMD64 and ARM64 are supported." >&2; exit 1 ;;
esac

packages=(ca-certificates curl tar gzip util-linux sudo)
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
install -d /usr/local/share/codex-feature /usr/local/bin
install -m 0755 "$feature_dir/oncreate.sh" /usr/local/share/codex-feature/oncreate.sh

# Resolve HOME at runtime: remoteUser and its UID can change after the build.
wrapper="$(mktemp)"
trap 'rm -f "$wrapper"' EXIT
cat > "$wrapper" <<'EOF'
#!/bin/sh
export CODEX_HOME="${CODEX_HOME:-/var/lib/codex}"
exec "$HOME/.local/bin/codex" -c 'cli_auth_credentials_store="file"' "$@"
EOF
install -m 0755 "$wrapper" /usr/local/bin/codex

echo "codex: dependencies prepared; the official installer runs on container creation."
