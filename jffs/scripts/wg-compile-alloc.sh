#!/bin/sh
set -eu

# Implements the contracts defined in contracts.inc.
# Any deviation is a bug.

IN_PLAN="plan.tsv"
OUT_ALLOC="alloc.tsv"

: "${WG_DUMP:=0}"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

fatal() {
	echo "❌ $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || fatal "Missing required command: $1"
}

check_tsv_field() {
	case "$1" in
		*"$'\t'"*|*"$'\n'"*|*"$'\r'"*|*"$'\0'"*)
			fatal "Forbidden character in TSV field: [$1]"
			;;
	esac
}

emit_row() {
	for field in "$@"; do
		check_tsv_field "$field"
	done
	printf '%s\t' "$@" | sed 's/\t$//'
	printf '\n'
}

# -----------------------------------------------------------------------------
# Preconditions
# -----------------------------------------------------------------------------

[ -f "$IN_PLAN" ] || fatal "Missing input file: $IN_PLAN"

require_cmd awk
require_cmd sort

# -----------------------------------------------------------------------------
# Extract unique (base, iface) pairs
# -----------------------------------------------------------------------------

tmp_pairs="$(mktemp)"
trap 'rm -f "$tmp_pairs"' EXIT

awk -F'\t' '
	NR > 1 {
		print $1 "\t" $2
	}
' "$IN_PLAN" | sort -u >"$tmp_pairs"

# -----------------------------------------------------------------------------
# Assign slots per iface
# -----------------------------------------------------------------------------

tmp_alloc="$(mktemp)"
trap 'rm -f "$tmp_pairs" "$tmp_alloc"' EXIT

awk -F'\t' '
{
	base = $1
	iface = $2

	if (!(iface in count)) {
		count[iface] = 0
	}

	count[iface]++
	slot = count[iface]

	print base "\t" iface "\t" slot
}
' "$tmp_pairs" >"$tmp_alloc"

# -----------------------------------------------------------------------------
# Emit alloc.tsv (optional)
# -----------------------------------------------------------------------------

if [ "$WG_DUMP" -eq 1 ]; then
	{
		emit_row base iface slot

		sort "$tmp_alloc" | while IFS="$(printf '\t')" read -r base iface slot; do
			emit_row "$base" "$iface" "$slot"
		done
	} >"$OUT_ALLOC"

	echo "✅ Generated $OUT_ALLOC"
else
	echo "ℹ️  WG_DUMP=0 — alloc.tsv not written"
fi
