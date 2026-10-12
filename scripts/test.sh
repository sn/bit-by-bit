#!/usr/bin/env sh
# Run each test file in its own process. `ecko test` runs every file in one
# process, and test files that start an in-process fake S3 server interfere
# with each other when they share one.
set -u
cd "$(dirname "$0")/.."
status=0
for f in ${@:-tests/*_test.ecko tests/live/*_test.ecko}; do
    ecko test "$f" || status=1
done
exit $status
