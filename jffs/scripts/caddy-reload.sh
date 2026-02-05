#!/bin/sh
# jffs/scripts/caddy-reload.sh

CADDY_BIN="/tmp/mnt/sda/router/bin/caddy"
CADDY_CONF="/etc/caddy/Caddyfile"

if pidof caddy > /dev/null; then
    echo "[caddy] reloading configuration"
    $CADDY_BIN reload --config $CADDY_CONF || {
        echo "[caddy] reload failed, checking syntax..."
        $CADDY_BIN validate --config $CADDY_CONF && \
        echo "[caddy] syntax OK, manual restart required"
    }
else
    echo "[caddy] process not running, starting..."
    $CADDY_BIN run --config $CADDY_CONF --adapter caddyfile &
fi