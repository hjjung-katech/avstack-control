#!/usr/bin/env bash
# Stage 05 검증 — MORAI ROS2 native(rosbridge) 토픽 확인 + sim/wall offset 측정.
# 선행: run_rosbridge.sh 실행 중 + SIM 기동 + Network Settings 로 publish 활성화.
# echo 는 CLAUDE.md 규칙상 --once 만 사용.
set -uo pipefail

WS="${AVSTACK_WS:-$HOME/avstack/ros2_ws}"
OFFSET_TOPIC="${OFFSET_TOPIC:-/Ego_topic}"
OFFSET_TYPE="${OFFSET_TYPE:-EgoVehicleStatus}"
COUNT="${OFFSET_COUNT:-50}"
HERE="$(cd "$(dirname "$0")" && pwd)"

source /opt/ros/humble/setup.bash
[ -f "$WS/install/setup.bash" ] && source "$WS/install/setup.bash"
export ROS_LOCALHOST_ONLY=0

TS=$(date +%Y%m%d_%H%M%S)
LOG="$HOME/avstack/runs/stage05_verify_$TS.log"
{
  echo "== Stage 05 verify ($(date +%F' '%T)) =="
  echo "-- ros2 topic list --"
  timeout 8 ros2 topic list

  echo; echo "-- MORAI 토픽 필터 --"
  timeout 8 ros2 topic list | grep -v -E "^/(rosout|parameter_events|client_count|connected_clients)$" || true

  echo; echo "-- offset 대상 토픽 hz ($OFFSET_TOPIC, 5s) --"
  timeout 6 ros2 topic hz "$OFFSET_TOPIC" 2>&1 | head -4 || echo "(hz 측정 실패)"

  echo; echo "-- echo --once ($OFFSET_TOPIC) --"
  timeout 8 ros2 topic echo --once "$OFFSET_TOPIC" 2>&1 | head -25 || echo "(echo 실패)"

  echo; echo "-- sim/wall offset (n=$COUNT) --"
  timeout 40 python3 "$HERE/offset_probe.py" --topic "$OFFSET_TOPIC" --type "$OFFSET_TYPE" --count "$COUNT" 2>&1
} | tee "$LOG"

echo; echo "EVIDENCE=$LOG"
echo "민감정보 점검:"; grep -i -E "token|license|auth|password|key|secret" "$LOG" && echo "[!] 위 항목 확인 요" || echo "  (없음)"
