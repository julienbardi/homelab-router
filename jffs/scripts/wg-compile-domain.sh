#!/bin/sh
set -eu

IN_DOMAIN="domain.tsv"
OUT_PLAN="plan.tsv"
: "${WG_DUMP:=0}"

[ -f "$IN_DOMAIN" ] || {
    echo "❌ Missing input file: $IN_DOMAIN" >&2
    exit 1
}

busybox awk -F'[ \t]+' '
NR == 1 {
    # Minimal sanity check: required columns present
    if ($1 != "base" || $2 != "iface" || $3 != "profile") {
        print "❌ domain.tsv missing required columns" > "/dev/stderr"
        print "   got: [" $0 "]" > "/dev/stderr"
        exit 1
    }
    next
}

{
    base    = $1
    iface   = $2
    profile = $3
    server  = $4
    vpn4    = $5
    vpn6    = $6

    print base "\t" iface "\t" profile "\t" server "\t" vpn4 "\t" vpn6
}
' "$IN_DOMAIN" >"$OUT_PLAN"

[ "$WG_DUMP" -eq 1 ] && echo "✅ Generated $OUT_PLAN"
