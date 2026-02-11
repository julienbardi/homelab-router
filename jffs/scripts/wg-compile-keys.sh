#!/bin/sh
set -eu

# Implements the contracts defined in contracts.inc.
# Any deviation is a bug.

IN_ALLOC="alloc.tsv"
OUT_KEYS="keys.tsv"
KEY_ROOT="/jffs/scripts/wireguard/keys"

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

[ -f "$IN_ALLOC" ] || fatal "Missing input file: $IN_ALLOC"

require_cmd wg
require_cmd awk
require_cmd sort

mkdir -p "$KEY_ROOT"

# -----------------------------------------------------------------------------
# Generate keys idempotently
# -----------------------------------------------------------------------------

tmp_keys="$(mktemp)"
trap 'rm -f "$tmp_keys"' EXIT

awk -F'\t' '
	NR > 1 {
		print $1 "\t" $2
	}
' "$IN_ALLOC" | sort -u | while IFS="$(printf '\t')" read -r base iface; do
	dir="$KEY_ROOT/$iface"
	key="$dir/$base.key"

	mkdir -p "$dir"

	if [ ! -f "$key" ]; then
		wg genkey >"$key"
		chmod 600 "$key"
	fi

	pub="$(wg pubkey <"$key")"
	printf '%s\t%s\t%s\n' "$base" "$iface" "$pub" >>"$tmp_keys"
done

# -----------------------------------------------------------------------------
# Emit keys.tsv (optional)
# -----------------------------------------------------------------------------

if [ "$WG_DUMP" -eq 1 ]; then
	{
		emit_row base iface pubkey
		sort "$tmp_keys" | while IFS="$(printf '\t')" read -r base iface pub; do
			emit_row "$base" "$iface" "$pub"
		done
	} >"$OUT_KEYS"

	echo "✅ Generated $OUT_KEYS"
else
	echo "ℹ️  WG_DUMP=0 — keys.tsv not written"
fi
