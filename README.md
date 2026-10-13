# bit-by-bit

Incremental backups of a Linux machine to S3-compatible object storage (AWS S3,
Google Cloud Storage, Cloudflare R2, Backblaze B2, MinIO, Wasabi), run as a
systemd service. Written in [Ecko](https://ecko.sh).

- Each local file becomes one object, and only changed files are uploaded.
- Before a remote file is overwritten or deleted, the old copy is moved under
  `_versions/`, so local mistakes can be undone. Old versions are pruned after
  `keep_versions_days`.
- Uploads are checked by the provider against a SHA-256 of the content. A
  crash at any point leaves the backup consistent, and the next run finishes
  the work.
- A missing or unreadable directory never causes remote deletes, and neither
  does a directory that has suddenly become empty although files were backed
  up from it (an unmounted drive).
- Changing a job's destination or prefix triggers a full upload to the new
  place.
- Server-side encryption is on by default, and every request goes over HTTPS.

## Install

Requires Ecko 0.66 or later. The one dependency, the
[`xml`](https://github.com/ecko-lang/xml) package, is vendored in `vendor/` and
pinned in `ecko.lock`; `ecko install` restores it if it's missing.

```bash
ecko build main.ecko -o bit-by-bit
sudo ./deploy/install.sh
```

The installer puts the binary in `/usr/local/bin` and an example config in
`/etc/bit-by-bit/config.json`, and registers the systemd unit. It does not
enable the service. Then:

```bash
sudoedit /etc/bit-by-bit/config.json
sudo bit-by-bit check-config
sudo bit-by-bit run --dry-run
sudo systemctl enable --now bit-by-bit
```

## Configure

See `deploy/config.example.json`. The full field reference is in
`docs/superpowers/specs/2026-10-12-bit-by-bit-design.md`, section 3.

- **Schedules:** `{ "every": "6h" }` (minimum `1m`) or
  `{ "daily_at": "02:30" }` (local time). A run missed while the machine was
  off happens once at startup.
- **Credentials:** a `KEY=value` file, mode 600:

  ```
  ACCESS_KEY_ID=...
  SECRET_ACCESS_KEY=...
  ```

  Alternatively set `BBB_<DEST>_ACCESS_KEY_ID` and
  `BBB_<DEST>_SECRET_ACCESS_KEY` in the environment, where `<DEST>` is the
  destination name upper-cased with `-` replaced by `_`.
- **Reload:** `systemctl reload bit-by-bit` sends SIGHUP. An invalid config is
  rejected and the old one stays active.

### Providers

| Provider | Destination settings |
|---|---|
| AWS S3 | `"provider": "s3"`, `"endpoint": "https://s3.<region>.amazonaws.com"`, `"region": "<region>"` |
| Google Cloud Storage | `"provider": "gcs"`. Create HMAC keys for a service account (Cloud Storage > Settings > Interoperability) and put them in the credentials file. |
| Cloudflare R2 | `"provider": "s3"`, `"endpoint": "https://<account-id>.r2.cloudflarestorage.com"`, `"region": "auto"` |
| Backblaze B2 | `"provider": "s3"`, `"endpoint": "https://s3.<region>.backblazeb2.com"`, `"region": "<region>"` |
| MinIO (local) | `"provider": "s3"`, `"endpoint": "http://127.0.0.1:9000"`, `"region": "us-east-1"`, `"path_style": true`, `"allow_insecure": true`, `"server_side_encryption": false` (MinIO without a KMS rejects SSE requests) |

## Use

```bash
bit-by-bit status                      # last run, next run and problems for each job
bit-by-bit run home                    # run a job now (exit 0 ok, 2 partial, 1 failed)
bit-by-bit ls home --at 2026-10-01T12:00:00Z
bit-by-bit restore home --path /home/me/Documents --to /tmp/restore
bit-by-bit restore home --at 2026-10-01T12:00:00Z
journalctl -u bit-by-bit -p warning    # problems and failures
```

Restore never overwrites existing files unless you pass `--overwrite`. It
checks every file against its stored SHA-256, and puts back each file's mode
and modification time.

If the state database is lost, `bit-by-bit run home --rebuild-state` rebuilds
it from the bucket.

## Dashboard

The daemon can serve a read-only status page. It's off unless the config has:

```json
"dashboard": { "listen": "127.0.0.1:8484" }
```

| URL | What |
|---|---|
| `http://127.0.0.1:8484/` | Each job's status, last and next run, counts, errors, problems and recent runs. Refreshes every 30 seconds. |
| `/api/status` | The same data as JSON. |
| `/healthz` | `200 ok`, or `503` listing why: a job's last run failed, or it hasn't run for more than twice its interval. Point an uptime monitor at it. |

The page has no login, so it only binds to loopback addresses (`127.0.0.1`,
`localhost`, `::1`). To reach it from elsewhere, use an SSH tunnel
(`ssh -L 8484:127.0.0.1:8484 host`), or set `"allow_remote": true` deliberately.
The page has no buttons and can't change anything. If the port is taken, the
daemon logs an error and keeps backing up. Changing `listen` needs a service
restart.

## Remote layout

```
<prefix>/<absolute local path>                       current copy
<prefix>/_versions/<run time>/<absolute local path>  copy moved aside by that run
```

Objects carry `x-amz-meta-bbb-sha256`, `-mtime`, `-mode` and `-run`. Symlinks
are stored as empty objects with `x-amz-meta-bbb-symlink`.

## Develop

```bash
ecko test --jobs 4                # every test file, each in its own process
ecko test tests/sync_test.ecko
ecko check --strict main.ecko src/*.ecko tests/*.ecko testkit/*.ecko
```

Tests run offline against `testkit/fake_s3.ecko`, an in-memory S3 server that
checks signatures and payload hashes and can be told to fail requests.
