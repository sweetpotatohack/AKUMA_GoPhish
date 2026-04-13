#!/bin/bash
INSTALL_DIR="/root/sneaky-gophish-ssl-automation"
DOMAIN_ADMIN="admin.vtb.news"

# Тот же каталог, что и у deploy (admin.domain или admin.domain-0001)
pick_le_dir() {
  local best="" best_t=0 d t
  for d in "/etc/letsencrypt/live/$DOMAIN_ADMIN" /etc/letsencrypt/live/${DOMAIN_ADMIN}-*; do
    [ -f "$d/fullchain.pem" ] || continue
    t=$(stat -c %Y "$d/fullchain.pem" 2>/dev/null || echo 0)
    if [ "${t:-0}" -gt "${best_t:-0}" ]; then best_t=$t; best=$d; fi
  done
  [ -n "$best" ] && echo "$best" || echo "/etc/letsencrypt/live/$DOMAIN_ADMIN"
}

certbot renew --quiet
LE_DIR=$(pick_le_dir)
cp "$LE_DIR/fullchain.pem" "$INSTALL_DIR/ssl/admin.crt"
cp "$LE_DIR/privkey.pem"   "$INSTALL_DIR/ssl/admin.key"
cp "$LE_DIR/fullchain.pem" "$INSTALL_DIR/ssl/phish.crt"
cp "$LE_DIR/privkey.pem"   "$INSTALL_DIR/ssl/phish.key"
chmod 644 $INSTALL_DIR/ssl/*
cd $INSTALL_DIR && docker compose restart
