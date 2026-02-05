#!/bin/sh
# jffs/scripts/caddy-reload.sh

# Load existing secrets
if [ -f "/jffs/scripts/.ddns_confidential" ]; then
    . /jffs/scripts/.ddns_confidential
    export INFOMANIAK_API_TOKEN="$DDNSPASSWORD"
fi

CADDY_BIN="/tmp/mnt/sda/router/bin/caddy"
CADDY_CONF="/etc/caddy/Caddyfile"

# If Caddy is running, reload config
if pidof caddy > /dev/null; then
    echo "🔄 Reloading Caddy configuration"
    $CADDY_BIN reload --config "$CADDY_CONF" --adapter caddyfile || {
        echo "⚠️ Reload failed, checking syntax..."
        if $CADDY_BIN validate --config "$CADDY_CONF" --adapter caddyfile; then
            echo "🔍 Syntax OK, restarting..."
            $CADDY_BIN start --config "$CADDY_CONF" --adapter caddyfile
        else
            echo "❌ Syntax error, NOT restarting"
            exit 1
        fi
    }
    exit 0
fi

# If not running, start it
echo "🚀 Starting Caddy..."
$CADDY_BIN start --config "$CADDY_CONF" --adapter caddyfile
