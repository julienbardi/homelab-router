#!/bin/sh
set -eu

# Implements the contracts defined in contracts.inc.
# Any deviation is a bug.

DOMAIN_FILE="/jffs/scripts/wireguard/domain.yaml"
OUT_PLAN="plan.tsv"

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

[ -f "$DOMAIN_FILE" ] || fatal "domain.yaml not found: $DOMAIN_FILE"

require_cmd yq
require_cmd sort

# -----------------------------------------------------------------------------
# Parse domain.yaml
# -----------------------------------------------------------------------------

nodes="$(yq -r '.nodes[]' "$DOMAIN_FILE")"
ifaces="$(yq -r '.interfaces | keys[]' "$DOMAIN_FILE")"
profiles="$(yq -r '.profiles | keys[]' "$DOMAIN_FILE")"

[ -n "$nodes" ] || fatal "No nodes defined"
[ -n "$ifaces" ] || fatal "No interfaces defined"
[ -n "$profiles" ] || fatal "No profiles defined"

# Load constraints into a simple lookup table:
# key = iface|profile → disallowed
constraints="$(yq -r '
  .constraints[]? |
  .iface as $iface |
  .disallow_profiles[] |
  "\($iface)|\(.)"
' "$DOMAIN_FILE" || true)"

is_disallowed() {
	key="$1|$2"
	printf '%s\n' "$constraints" | grep -qx "$key"
}

# -----------------------------------------------------------------------------
# Enumerate domain
# -----------------------------------------------------------------------------

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for node in $nodes; do
	for iface in $ifaces; do
		for profile in $profiles; do
			if is_disallowed "$iface" "$profile"; then
				continue
			fi
			printf '%s\t%s\t%s\n' "$node" "$iface" "$profile" >>"$tmp"
		done
	done
done

# -----------------------------------------------------------------------------
# Emit plan.tsv (optional)
# -----------------------------------------------------------------------------

if [ "$WG_DUMP" -eq 1 ]; then
	{
		emit_row base iface profile
		sort "$tmp" | while IFS="$(printf '\t')" read -r base iface profile; do
			emit_row "$base" "$iface" "$profile"
		done
	} >"$OUT_PLAN"

	echo "✅ Generated $OUT_PLAN"
else
	echo "ℹ️  WG_DUMP=0 — plan.tsv not written"
fi
