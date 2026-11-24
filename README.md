[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/filerise?utm_medium=integration&utm_source=button&utm_campaign=filerise)

# FileRise on Railway

One-click [FileRise](https://github.com/error311/FileRise), a self-hosted web file manager with resumable uploads, per-folder ACLs, share links and WebDAV, for [Railway](https://railway.com).

- **Version:** FileRise **v3.47.0**, official image `error311/filerise-docker:v3.47.0@sha256:c72c007f466040cfcc12e9f30164b5e920126994a5282650c3939fe7ece2b33c`
- **Services:** one, `FileRise` (Apache + PHP 8.3), public on Railway's HTTPS domain
- **Storage:** one Railway volume at `/data` with `uploads/`, `users/`, `metadata/` and `sessions/`
- **Health check:** `GET /healthz` (200 once the admin exists and the volume is writable)
- **Memory:** runs on Railway's 0.5 GB plans; a 200 MB upload and download used about 25 MB of RAM in our tests

## After deploy

1. Open the `FileRise` service → **Variables** and copy `FILERISE_ADMIN_PASSWORD`.
2. Sign in at the service URL as `admin` with that password.
3. Change the password (profile menu → change password), and add users and folder permissions in the **Admin Panel**.
4. Optional: turn on WebDAV (Admin Panel → WebDAV) and connect to `https://YOUR-DOMAIN/webdav.php`.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `FILERISE_ADMIN_PASSWORD` | `${{secret(24, …)}}` | First admin's password, generated on deploy. Read only on the first boot. |
| `FILERISE_ADMIN_USER` | `admin` | First admin's user name. |
| `TIMEZONE` | `UTC` | Time zone for dates in the UI. |
| `PORT` | `8080` | Port Apache listens on. |

Optional, not set by the template: `VIRUS_SCAN_ENABLED=true` turns on ClamAV upload scanning (needs more than 1 GB of RAM); `FR_PUBLISHED_URL` sets the public URL used in share links when you put a custom domain in front; `FR_ENCRYPTION_MASTER_KEY` supplies the folder-encryption key from a variable instead of the admin panel. See upstream's [environment variable reference](https://github.com/error311/FileRise/blob/v3.47.0/docs/wiki/Environment-Variables-Full-Reference.md).

## What the wrapper does

`railway-start.sh` runs before upstream's own `start.sh`:

- links `/var/www/{uploads,users,metadata,sessions}` to the `/data` volume, and refuses to start without a mounted volume (so files never land on the container's throwaway disk);
- generates `metadata/persistent_tokens.key` on a fresh volume;
- creates the first admin from `FILERISE_ADMIN_PASSWORD` **before Apache listens**, which closes FileRise's first-visitor setup page; it exits non-zero if that fails;
- sizes Apache's prefork workers and PHP's `memory_limit` from the service's memory limit (Railway hosts show dozens of CPUs);
- listens on `$PORT`, marks requests with `X-Forwarded-Proto: https` as HTTPS (Secure cookies), trusts Railway's proxy ranges for client IPs (login lockouts), and keeps ClamAV off by default.

If Apache dies, the container exits non-zero and Railway's `ON_FAILURE` restart policy brings it back.

## Updates

The template's service builds from this repository's `main` branch. When we bump the pinned FileRise version here, Railway shows everyone who deployed the template an "update available" notice; read [CHANGELOG.md](CHANGELOG.md) first, then apply it from your project. Data on the volume is kept.

## Licence

FileRise is MIT licensed by its authors. This wrapper is MIT licensed too.
