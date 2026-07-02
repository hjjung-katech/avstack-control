#!/usr/bin/env bash
# record_stage.sh <stage> <PASS|FAIL> "<summary>" "<evidence-path>" "<next>"
# Appends one row to records/stages.tsv (columns: date stage status summary evidence next).
# Never edit the TSV by hand — use this script only.
set -euo pipefail

usage() { echo "usage: $0 <stage> <PASS|FAIL> \"<summary>\" \"<evidence>\" \"<next>\"" >&2; exit 2; }
[ "$#" -eq 5 ] || usage

stage="$1"; status="$2"; summary="$3"; evidence="$4"; next="$5"
case "$status" in PASS|FAIL) ;; *) echo "[ERROR] status must be PASS or FAIL" >&2; exit 2;; esac

TSV="$(cd "$(dirname "$0")/.." && pwd)/records/stages.tsv"
mkdir -p "$(dirname "$TSV")"
[ -f "$TSV" ] || printf 'date\tstage\tstatus\tsummary\tevidence\tnext\n' > "$TSV"

# strip tabs/newlines from free-text fields to keep TSV intact
clean() { printf '%s' "$1" | tr '\t\n' '  '; }
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date +%F)" "$(clean "$stage")" "$status" "$(clean "$summary")" "$(clean "$evidence")" "$(clean "$next")" >> "$TSV"
echo "[OK] stage recorded -> $TSV"
