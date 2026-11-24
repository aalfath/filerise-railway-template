# Deploy and Host FileRise on Railway

FileRise is an open-source (MIT), self-hosted web file manager. It gives you drag-and-drop and resumable uploads, folder trees, previews, tags and search, per-folder access rules (ACLs), password-protected share links, a trash bin, ZIP download and extraction, optional folder encryption at rest, and a WebDAV endpoint for desktop clients. It's a single PHP app that keeps its data in plain files, so it needs no database.

## About Hosting FileRise

This template runs one FileRise service built from the official `error311/filerise-docker` image (v3.47.0, pinned by digest), with one Railway volume at `/data` that holds your uploads, users, settings, share links and login sessions. On the first boot the service creates an `admin` account from a generated password before it opens its port, so nobody can claim the instance through the setup page. Open the service's **Variables** tab, copy `FILERISE_ADMIN_PASSWORD`, sign in at your Railway URL, and change the password under your profile. Railway handles HTTPS, and the health check at `/healthz` reports ready only once the admin exists and the volume is writable.

## Common Use Cases

* A private Dropbox-style file space for yourself, your family or a small team
* Sharing files and folders with clients through expiring, password-protected links
* A WebDAV drive (`https://YOUR-DOMAIN/webdav.php`) for macOS Finder, Windows or rclone

## Dependencies for FileRise Hosting

* A Railway volume mounted at `/data` (included in the template)
* No database, cache or external service

### Deployment Dependencies

* FileRise: [github.com/error311/FileRise](https://github.com/error311/FileRise) ([release v3.47.0](https://github.com/error311/FileRise/releases/tag/v3.47.0), [docs](https://github.com/error311/FileRise/wiki))
* Official image: [error311/filerise-docker](https://hub.docker.com/r/error311/filerise-docker)
* Template source: [aalfath/filerise-railway-template](https://github.com/aalfath/filerise-railway-template)

### Implementation Details

The template deploys one service, **FileRise** (Apache with PHP 8.3), and one volume at `/data`. Variables:

* `FILERISE_ADMIN_PASSWORD`: generated on deploy; the first admin's password. Only read on the first boot, so changing it later does nothing; change the password inside FileRise.
* `FILERISE_ADMIN_USER`: first admin's user name (default `admin`).
* `TIMEZONE`: time zone for dates in the UI (default `UTC`).

WebDAV is off by default: turn it on under Admin Panel → WebDAV. The image includes the ClamAV virus scanner, but it needs more than 1 GB of RAM and a signature download, so it stays off; set `VIRUS_SCAN_ENABLED=true` only on a service with that much memory. Pro-only features (groups, client portals, AI workspace, extra storage sources) need a FileRise Pro licence and are not part of this template. FileRise runs comfortably in 0.5 GB of RAM: in our tests a 200 MB upload and download used about 25 MB. Uploads are limited to 5 GB per request. Back up the `/data` volume, which also holds `metadata/persistent_tokens.key`. If you turn on folder encryption, keep a copy of its key somewhere else.

**Updates:** the service builds from the template's GitHub repository. When a new FileRise release is tested, we update the pinned version there and Railway shows you an update notice. Read the repository's CHANGELOG, then apply the update when you're ready. Your data on the volume is kept.

## Why Deploy FileRise on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying FileRise on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
