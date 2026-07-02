#!/usr/bin/env bash
# record_issue.sh <ID> <stage> <OPEN|RESOLVED> <HIGH|MED|LOW> "<symptom>" "<hypothesis>" "<evidence>" "<next>" ["<resolution>"]
# Appends one row to records/issues.tsv
# (columns: id date stage status severity symptom hypothesis evidence next resolution).
# Never edit the TSV by hand — use this script only.
set -euo pipefail

usage() { echo "usage: $0 <ID> <stage> <OPEN|RESOLVED> <HIGH|MED|LOW> \"<symptom>\" \"<hypothesis>\" \"<evidence>\" \"<next>\" [\"<resolution>\"]" >&2; exit 2; }
[ "$#" -ge 8 ] && [ "$#" -le 9 ] || usage

id="$1"; stage="$2"; status="$3"; severity="$4"; symptom="$5"; hypothesis="$6"; evidence="$7"; next="$8"; resolution="${9:-}"
case "$status" in OPEN|RESOLVED) ;; *) echo "[ERROR] status must be OPEN or RESOLVED" >&2; exit 2;; esac
case "$severity" in HIGH|MED|LOW) ;; *) echo "[ERROR] severity must be HIGH, MED or LOW" >&2; exit 2;; esac

TSV="$(cd "$(dirname "$0")/.." && pwd)/records/issues.tsv"
mkdir -p "$(dirname "$TSV")"
[ -f "$TSV" ] || printf 'id\tdate\tstage\tstatus\tseverity\tsymptom\thypothesis\tevidence\tnext\tresolution\n' > "$TSV"

clean() { printf '%s' "$1" | tr '\t\n' '  '; }
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(clean "$id")" "$(date +%F)" "$(clean "$stage")" "$status" "$severity" \
  "$(clean "$symptom")" "$(clean "$hypothesis")" "$(clean "$evidence")" "$(clean "$next")" "$(clean "$resolution")" >> "$TSV"
echo "[OK] issue recorded -> $TSV"
