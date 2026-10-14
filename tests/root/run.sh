#!/bin/sh
# Run tests as root in a throwaway container, for the checks only root can
# make (restoring files to other owners). Needs Docker. Downloads nothing:
# the image holds just this machine's ecko and the libraries it links, and
# the repo is mounted read-only so root leaves nothing behind in it.
#
#   tests/root/run.sh                         # the restore tests
#   tests/root/run.sh tests/sync_test.ecko    # or any others
set -eu

repo=$(cd "$(dirname "$0")/../.." && pwd)
ecko=$(command -v ecko) || { echo "error: ecko is not on PATH" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "error: needs docker" >&2; exit 1; }
[ $# -gt 0 ] || set -- tests/restore_test.ecko

ctx=$(mktemp -d)
trap 'rm -rf "$ctx"' EXIT
for f in "$ecko" $(ldd "$ecko" | grep -o '/[^ ]*'); do
    mkdir -p "$ctx/root$(dirname "$f")"
    cp -L "$f" "$ctx/root$f"
done
printf 'FROM scratch\nCOPY root/ /\nENV HOME=/tmp PATH=%s\n' "$(dirname "$ecko")" >"$ctx/Dockerfile"
image=bit-by-bit-root-test
docker build -q -t "$image" "$ctx" >/dev/null

docker run --rm --network none --tmpfs /tmp:exec,mode=1777 -v "$repo:/src:ro" -w /src "$image" ecko test "$@"
