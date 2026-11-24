# Changelog

## v3.47.0-1 (2026-11-24)

First release of the Railway template.

- FileRise v3.47.0, official image pinned by digest (`sha256:c72c007f…2b33c`). This release includes upstream's fixes for GHSA-8c2p-gm97-35cv (folder operations outside the authorised subtree) and the v3.46.0 advisories (share-link scope, archive extraction ACLs, WebDAV lockout).
- One Railway volume at `/data` for uploads, users, metadata and sessions.
- Admin created on first boot from a generated `FILERISE_ADMIN_PASSWORD`; the setup page is never open.
- `/healthz` health check; Apache and PHP sized from the memory limit; ClamAV off by default.
