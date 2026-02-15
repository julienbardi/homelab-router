#!/bin/sh
set -eu

IN_PLAN="plan.tsv"
OUT_ALLOC="alloc.tsv"
: "${WG_DUMP:=0}"

[ -f "$IN_PLAN" ] || {
	echo "❌ Missing input file: $IN_PLAN" >&2
	exit 1
}

busybox awk -F'\t' '
NR == 1 {
	if ($0 != "base\tiface\tprofile\tserver\tvpn4_cidr\tvpn6_cidr") {
		print "❌ Invalid header in plan.tsv" > "/dev/stderr"
		exit 1
	}
	next
}

{
	base  = $1
	iface = $2
	v4    = $5
	v6    = $6

	key = base "\t" iface
	if (!(key in idx)) {
		idx[key] = ++count[iface]
	}

	if (v4 != "") {
		split(v4, a, "/")
		addr = a[1]
		sub(/\.[0-9]+$/, "." (idx[key] + 1), addr)
		rows[++n] = base "\t" iface "\t" addr "\t" v4
	}

	if (v6 != "") {
		split(v6, a, "/")
		addr = a[1]
		sub(/::.*$/, "::" (idx[key] + 1), addr)
		rows[++n] = base "\t" iface "\t" addr "\t" v6
	}
}

END {
	print "base\tiface\taddr\tcidr"
	for (i = 1; i <= n; i++) {
		print rows[i]
	}
}
' "$IN_PLAN" >"$OUT_ALLOC"

[ "$WG_DUMP" -eq 1 ] && echo "✅ Generated $OUT_ALLOC"
