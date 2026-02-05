#!/bin/sh
set -eu

echo "📡 Installing DynDNS script..."
cp ddns/ddns-start /jffs/scripts/ddns-start
chmod 755 /jffs/scripts/ddns-start

echo "📁 Ensure your secrets exist at /jffs/scripts/.ddns_confidential"
echo "✨ Done."
