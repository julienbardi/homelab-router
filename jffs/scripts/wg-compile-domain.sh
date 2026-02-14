#!/bin/sh
set -eu; umask 077

# Implements the contracts defined in contracts.inc.
# Any deviation is a bug.

# -----------------------------------------------------------------------------
# Execution environment invariants
# -----------------------------------------------------------------------------

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

LC_ALL=C
export LC_ALL

: "${DOMAIN_FILE:=/jffs/scripts/wireguard/domain.tsv}"
: "${OUT_PLAN:=plan.tsv}"

PHASE="init"

: "${WG_DUMP:=0}"

TAB="$(printf '\t')"
NL="$(printf '\n')"
CR="$(printf '\r')"

fatal() {
	printf '❌ [%s] %s\n' "$PHASE" "$*" >&2
	exit 1
}

AWK="busybox awk"
SORT="busybox sort"
CAT="busybox cat"

busybox awk 'BEGIN{exit 0}' </dev/null || fatal "busybox awk not available"
busybox sort </dev/null >/dev/null 2>&1 || fatal "busybox sort not available"
busybox cat </dev/null >/dev/null 2>&1 || fatal "busybox cat not available"


if command -v mktemp >/dev/null 2>&1; then HAVE_MKTEMP=1; else HAVE_MKTEMP=0; fi
if [ -n "${RANDOM+x}" ]; then HAVE_RANDOM=1; else HAVE_RANDOM=0; fi

make_tmp() {
	prefix=$1

	if [ "$HAVE_MKTEMP" -eq 1 ]; then
		mktemp "/tmp/${prefix}.XXXXXX" \
			|| fatal "mktemp failed for $prefix"
	elif [ "$HAVE_RANDOM" -eq 1 ]; then
		printf '/tmp/%s.%s.%s\n' "$prefix" "$$" "$RANDOM"
	else
		printf '/tmp/%s.%s\n' "$prefix" "$$"
	fi
}

check_tsv_field() {
	case "$1" in
		*"$TAB"*|*"$NL"*|*"$CR"*)
			fatal "Forbidden character in TSV field: [$1]"
			;;
	esac
}

check_no_outer_space() {
	case "$1" in
		" "*) fatal "Leading space in field: [$1]" ;;
		*" ") fatal "Trailing space in field: [$1]" ;;
	esac
}

check_token() {
	field_value=$1
	field_name=$2

	case "$field_value" in
		'') fatal "Empty $field_name field" ;;
		*[!A-Za-z0-9_-]*)
			fatal "Invalid characters in $field_name: [$field_value]"
			;;
	esac

	# max 32 characters
	[ "${#field_value}" -le 32 ] || fatal "$field_name too long (max 32): [$field_value]"
}

check_iface() {
	value=$1

	case "$value" in
		'') fatal "Empty iface field" ;;
		*[!A-Za-z0-9.-]*)
			fatal "Invalid iface characters (allowed: A-Z a-z 0-9 . -): [$value]"
			;;
	esac

	# max 15 chars (Linux IFNAMSIZ-1)
	[ "${#value}" -le 15 ] || fatal "iface too long (max 15): [$value]"
}

[ -f "$DOMAIN_FILE" ] || fatal "domain.tsv not found: $DOMAIN_FILE"

# -----------------------------------------------------------------------------
# Header invariant
# -----------------------------------------------------------------------------
PHASE="header"
IFS="$TAB" read -r h_base h_iface h_profile h_extra <"$DOMAIN_FILE" \
	|| fatal "Failed to read domain.tsv header"

[ "$h_base" = "base" ]        || fatal "Invalid header: expected 'base', got '$h_base'"
[ "$h_iface" = "iface" ]      || fatal "Invalid header: expected 'iface', got '$h_iface'"
[ "$h_profile" = "profile" ]  || fatal "Invalid header: expected 'profile', got '$h_profile'"
[ -z "${h_extra:-}" ]         || fatal "Invalid header: too many fields"

PHASE="validate"

tmp="$(make_tmp wg-domain)"
tmp_unsorted="$(make_tmp wg-domain.unsorted)"

: >"$tmp" || fatal "Failed to create tmp file: $tmp"
: >"$tmp_unsorted" || fatal "Failed to create tmp_unsorted file: $tmp_unsorted"

cleanup() {
	rm -f "$tmp" "$tmp_unsorted"
}
trap cleanup EXIT

$AWK 'NR>1 { print }' "$DOMAIN_FILE" >"$tmp_unsorted" || fatal "Failed to read domain.tsv body"

while IFS="$TAB" read -r base iface profile extra; do
	[ -z "${extra:-}" ] || fatal "Too many fields in domain.tsv row"

	check_tsv_field "$base"
	check_tsv_field "$iface"
	check_tsv_field "$profile"

	check_no_outer_space "$base"
	check_no_outer_space "$iface"
	check_no_outer_space "$profile"

	check_token "$base" "base"
	check_iface "$iface"

	case "$profile" in
		lan|wan|lan+wan) ;;
		*) fatal "Invalid profile value: [$profile]" ;;
	esac

	printf '%s\t%s\t%s\n' "$base" "$iface" "$profile"
done <"$tmp_unsorted" | $SORT >"$tmp" || fatal "Failed to sort validated rows"

# -----------------------------------------------------------------------------
# Uniqueness invariant: (base, iface, profile) must be unique
# -----------------------------------------------------------------------------
PHASE="unique"
prev_key=""
while IFS="$TAB" read -r base iface profile; do
	key="${base}${TAB}${iface}${TAB}${profile}"
	if [ "$key" = "$prev_key" ]; then
		fatal "Duplicate row for base='$base', iface='$iface', profile='$profile'"
	fi
	prev_key="$key"
done <"$tmp"

PHASE="emit"
if [ "$WG_DUMP" -eq 1 ]; then
	{
		printf 'base\tiface\tprofile\n'
		$CAT "$tmp"
	} >"$OUT_PLAN"
	printf '✅ Generated %s\n' "$OUT_PLAN"
else
	printf 'ℹ️  WG_DUMP=0 — plan.tsv not written\n'
fi
