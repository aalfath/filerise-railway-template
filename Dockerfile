# FileRise for Railway: the official image, pinned by version and digest,
# plus a small start script that puts all state on one Railway volume (/data),
# creates the admin before Apache opens the port, and sizes Apache/PHP from
# the service's memory limit.
FROM error311/filerise-docker:v3.47.0@sha256:c72c007f466040cfcc12e9f30164b5e920126994a5282650c3939fe7ece2b33c

# Plain HTTP only (Railway terminates TLS); keep a single MPM (prefork, needed by mod_php).
RUN a2dismod -q -f ssl >/dev/null 2>&1 || true; \
    a2dismod -q -f mpm_event mpm_worker >/dev/null 2>&1 || true; \
    a2enmod -q mpm_prefork setenvif >/dev/null; \
    sed -i '/Listen 443/d' /etc/apache2/ports.conf; \
    printf '%s\n' \
      '# Railway terminates TLS at its edge and sends X-Forwarded-Proto.' \
      'SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on' \
      '# Plain health path for Railway (it rejects paths with a dot).' \
      'Alias /healthz /usr/local/lib/filerise-railway/healthz.php' \
      '<Directory /usr/local/lib/filerise-railway>' \
      '  Require all denied' \
      '  <Files healthz.php>' \
      '    Require all granted' \
      '  </Files>' \
      '</Directory>' \
      > /etc/apache2/conf-available/railway-proxy.conf; \
    a2enconf -q railway-proxy; \
    mkdir -p /var/www/metadata/log && apache2ctl -t 2>&1 | grep -q 'Syntax OK' && rm -r /var/www/metadata/log

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=0644 healthz.php /usr/local/lib/filerise-railway/healthz.php
COPY --chmod=0644 bootstrap-admin.php /usr/local/lib/filerise-railway/bootstrap-admin.php

RUN chmod 755 /usr/local/lib/filerise-railway

CMD ["/usr/local/bin/railway-start.sh"]
