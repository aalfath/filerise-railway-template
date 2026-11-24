#!/bin/bash
# Railway wrapper for the official FileRise image.
# - keeps every piece of state on one Railway volume (/data)
# - creates the admin from FILERISE_ADMIN_PASSWORD before Apache listens
# - sizes Apache prefork and PHP from the service's memory limit
# - then hands over to upstream's /usr/local/bin/start.sh (Apache in the foreground)
# Any failure exits non-zero so Railway's ON_FAILURE restart policy applies.
set -euo pipefail

DATA_DIR="${FILERISE_DATA_DIR:-/data}"
log() { echo "[railway] $*"; }

# 1) Require a persistent volume, so uploads and users are never written to the container's throwaway disk.
if ! mountpoint -q "$DATA_DIR" && [ "${FILERISE_ALLOW_EPHEMERAL:-false}" != "true" ]; then
  echo "[railway] ERROR: $DATA_DIR is not a mounted volume. Attach a Railway volume at $DATA_DIR (or set FILERISE_ALLOW_EPHEMERAL=true for a throwaway test)." >&2
  exit 1
fi

# 2) Point FileRise's data folders at the volume.
for d in uploads users metadata sessions; do
  src="$DATA_DIR/$d"; dst="/var/www/$d"
  mkdir -p "$src"
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] || { echo "[railway] ERROR: unexpected symlink $dst" >&2; exit 1; }
  else
    if [ -d "$dst" ] && [ -n "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
      echo "[railway] ERROR: $dst is not empty in the image; refusing to hide it" >&2; exit 1
    fi
    rm -r "$dst" 2>/dev/null || true
    ln -s "$src" "$dst"
  fi
done
# Small trees are normalised every boot; uploads only at the top level (a recursive chown of a big library would slow every start).
chown -R www-data:www-data "$DATA_DIR/users" "$DATA_DIR/metadata" "$DATA_DIR/sessions"
chown www-data:www-data "$DATA_DIR/uploads"
chmod 775 "$DATA_DIR/uploads" "$DATA_DIR/users" "$DATA_DIR/metadata"
chmod 700 "$DATA_DIR/sessions"

# 3) Pristine install: generate the token-encryption key on the volume BEFORE the admin is written
#    (upstream falls back to a legacy built-in key when users exist without a key file).
KEY_FILE="$DATA_DIR/metadata/persistent_tokens.key"
if [ -z "${PERSISTENT_TOKENS_KEY:-}" ] && [ ! -s "$KEY_FILE" ] && ! grep -q '[^[:space:]]' "$DATA_DIR/users/users.txt" 2>/dev/null; then
  umask 077
  openssl rand -hex 32 > "$KEY_FILE.tmp"
  mv "$KEY_FILE.tmp" "$KEY_FILE"
  umask 022
  chown www-data:www-data "$KEY_FILE"; chmod 600 "$KEY_FILE"
  log "generated metadata/persistent_tokens.key"
fi

# 4) First admin from generated variables (fails closed: no open setup wizard).
php /usr/local/lib/filerise-railway/bootstrap-admin.php
chown -R www-data:www-data "$DATA_DIR/users"
unset FILERISE_ADMIN_PASSWORD

# 5) Size Apache and PHP from the memory limit (Railway hosts show many CPUs; the cgroup is what counts).
mem_bytes=""
if [ -r /sys/fs/cgroup/memory.max ]; then mem_bytes="$(cat /sys/fs/cgroup/memory.max)"; fi
if ! [[ "$mem_bytes" =~ ^[0-9]+$ ]]; then mem_bytes=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 )); fi
mem_mb=$(( mem_bytes / 1024 / 1024 ))
workers=$(( mem_mb / 48 )); [ "$workers" -lt 6 ] && workers=6; [ "$workers" -gt 40 ] && workers=40
php_mem=$(( mem_mb / 3 )); [ "$php_mem" -lt 96 ] && php_mem=96; [ "$php_mem" -gt 512 ] && php_mem=512
WORKERS="${APACHE_MAX_WORKERS:-$workers}"
cat > /etc/apache2/mods-available/mpm_prefork.conf <<CONF
<IfModule mpm_prefork_module>
    StartServers            2
    MinSpareServers         2
    MaxSpareServers         4
    ServerLimit             ${WORKERS}
    MaxRequestWorkers       ${WORKERS}
    MaxConnectionsPerChild  1000
</IfModule>
CONF
for sapi in apache2 cli; do
  printf 'memory_limit=%sM\nopcache.memory_consumption=64\n' "${PHP_MEMORY_LIMIT_MB:-$php_mem}" > "/etc/php/8.3/$sapi/conf.d/99-zz-railway.ini"
done
log "memory limit ${mem_mb} MB -> Apache MaxRequestWorkers ${WORKERS}, PHP memory_limit ${PHP_MEMORY_LIMIT_MB:-$php_mem}M"

# 6) Settings for Railway. ClamAV needs about 1.5 GB of RAM and a signature download, so it stays off unless enabled.
export HTTP_PORT="${PORT:-8080}"
export TIMEZONE="${TIMEZONE:-UTC}"
export VIRUS_SCAN_ENABLED="${VIRUS_SCAN_ENABLED:-false}"
if [ "$VIRUS_SCAN_ENABLED" = "true" ]; then export CLAMAV_AUTO_UPDATE="${CLAMAV_AUTO_UPDATE:-true}"; else export CLAMAV_AUTO_UPDATE=false; fi
export SCAN_ON_START="${SCAN_ON_START:-false}"
export CHOWN_ON_START=false
# Railway's edge reaches the service from these ranges; trust them for the client IP (login lockouts are per IP).
export FR_TRUSTED_PROXIES="${FR_TRUSTED_PROXIES:-100.64.0.0/10,152.233.0.0/16}"
export FR_IP_HEADER="${FR_IP_HEADER:-X-Forwarded-For}"

apache2ctl -t >/dev/null 2>&1 || { apache2ctl -t; exit 1; }
exec /usr/local/bin/start.sh
