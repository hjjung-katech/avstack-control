#!/usr/bin/env bash
# record_decision.sh <ADR-ID> <ACCEPTED|REJECTED|SUPERSEDED> "<decision>" "<reason>"
# Appends one row to records/decisions.tsv (columns: id date status decision reason).
# Never edit the TSV by hand — use this script only.
set -euo pipefail

usage() { echo "usage: $0 <ADR-ID> <ACCEPTED|REJECTED|SUPERSEDED> \"<decision>\" \"<reason>\"" >&2; exit 2; }
[ "$#" -eq 4 ] || usage

id="$1"; status="$2"; decision="$3"; reason="$4"
case "$status" in ACCEPTED|REJECTED|SUPERSEDED) ;; *) echo "[ERROR] status must be ACCEPTED, REJECTED or SUPERSEDED" >&2; exit 2;; esac

TSV="$(cd "$(dirname "$0")/.." && pwd)/records/decisions.tsv"
mkdir -p "$(dirname "$TSV")"
[ -f "$TSV" ] || printf 'id\tdate\tstatus\tdecision\treason\n' > "$TSV"

clean() { printf '%s' "$1" | tr '\t\n' '  '; }
printf '%s\t%s\t%s\t%s\t%s\n' \
  "$(clean "$id")" "$(date +%F)" "$status" "$(clean "$decision")" "$(clean "$reason")" >> "$TSV"
echo "[OK] decision recorded -> $TSV"
