#!/bin/sh
set -eu

# Implements the contracts defined in contracts.inc.
# Any deviation is a bug.

IN_PLAN="plan.tsv"
OUT_ALLOC="alloc.tsv"
: "${WG_DUMP:=0}"

[ -f "$IN_PLAN" ] || {
	echo "❌ Missing input file: $IN_PLAN" >&2
	exit 1
}

if [ "$WG_DUMP" -eq 1 ]; then
	busybox awk -F'\t' '
	NR == 1 {
		if ($0 != "base\tiface\tprofile") {
			print "❌ Invalid header in plan.tsv" > "/dev/stderr"
			exit 1
		}
		next
	}
	{
		base = $1
		iface = $2
		key = base "\t" iface
		if (!(key in slot)) {
			slot[key] = ++count[iface]
		}
		rows[++n] = base "\t" iface "\t" slot[key]
	}
	END {
		print "base\tiface\tslot"
		for (i = 1; i <= n; i++) {
			print rows[i]
		}
	}
	' "$IN_PLAN" >"$OUT_ALLOC"
	echo "✅ Generated $OUT_ALLOC"
else
	busybox awk -F'\t' '
	NR == 1 {
		if ($0 != "base\tiface\tprofile") {
			print "❌ Invalid header in plan.tsv" > "/dev/stderr"
			exit 1
		}
		next
	}
	{ next }
	END { exit 0 }
	' "$IN_PLAN" >/dev/null
fi

