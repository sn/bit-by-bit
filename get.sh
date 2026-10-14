#!/bin/sh
# Download the latest bit-by-bit release for this machine, check it and
# install it as a systemd service:
#
#   curl -fsSL https://raw.githubusercontent.com/sn/bit-by-bit/main/get.sh | sh
#
# Set BBB_VERSION=v0.6.0 to install a particular release instead. Like
# deploy/install.sh, this never overwrites an existing config and never
# starts the service.
set -eu

REPO="https://github.com/sn/bit-by-bit"

fail() {
    echo "error: $*" >&2
    exit 1
}

# Everything runs from main, so a download cut off half-way runs nothing.
main() {
    [ "$(uname -s)" = "Linux" ] || fail "bit-by-bit runs on Linux only"
    case "$(uname -m)" in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        *) fail "no prebuilt binary for $(uname -m); build from source: $REPO#install" ;;
    esac
    for tool in curl tar sha256sum; do
        command -v "$tool" >/dev/null 2>&1 || fail "$tool is needed but not installed"
    done
    if [ "$(id -u)" -eq 0 ]; then
        sudo=""
    else
        command -v sudo >/dev/null 2>&1 || fail "run as root, or install sudo"
        sudo="sudo"
    fi

    version="${BBB_VERSION:-}"
    if [ -z "$version" ]; then
        # /releases/latest redirects to /releases/tag/<version>.
        latest=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") ||
            fail "couldn't reach $REPO"
        version="${latest##*/}"
        [ "$version" != "latest" ] || fail "no release published yet"
    fi

    name="bit-by-bit-$version-$arch-linux"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cd "$tmp"
    echo "downloading bit-by-bit $version for $arch"
    curl -fsSLO "$REPO/releases/download/$version/$name.tar.gz" ||
        fail "couldn't download $version; is it a release tag?"
    curl -fsSLO "$REPO/releases/download/$version/$name.tar.gz.sha256" ||
        fail "couldn't download the checksum for $version"
    sha256sum -c "$name.tar.gz.sha256" || fail "checksum mismatch, nothing installed"
    tar -xzf "$name.tar.gz"
    cd "$name"

    $sudo ./deploy/install.sh

    if systemctl is-active --quiet bit-by-bit 2>/dev/null; then
        echo
        echo "The service is running the old version. To switch: sudo systemctl restart bit-by-bit"
    fi
}

main "$@"
