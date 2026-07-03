#!/usr/bin/env bash
# Stage 05 검증 — MORAI ROS2 Native(CycloneDDS) 토픽 확인 + sim/wall offset 측정.
# 선행: SIM 기동 + Network Settings ROS2 Publisher(예: Ego Vehicle Status) 켜고 Connect + Play.
# echo 는 CLAUDE.md 규칙상 --once 만 사용.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"

EGO_TOPIC="${EGO_TOPIC:-/ego_vehicle_status}"
EGO_TYPE="${EGO_TYPE:-EgoVehicleStatus}"
COUNT="${OFFSET_COUNT:-50}"

# 데몬 재시작으로 최신 디스커버리 반영
ros2 daemon stop >/dev/null 2>&1; ros2 daemon start >/dev/null 2>&1

TS=$(date +%Y%m%d_%H%M%S)
LOG="$HOME/avstack/runs/stage05_verify_$TS.log"
{
  echo "== Stage 05 ROS2 Native verify ($(date +%F' '%T)) =="
  echo "RMW=$RMW_IMPLEMENTATION DOMAIN=$ROS_DOMAIN_ID"

  echo; echo "-- ros2 node list --"; timeout 8 ros2 node list

  echo; echo "-- ros2 topic list -t --"; timeout 8 ros2 topic list -t | sort

  echo; echo "-- MORAI 관련 토픽 필터 --"
  timeout 8 ros2 topic list -t | grep -Ei "clock|tf|ego|vehicle|gps|gnss|imu|lidar|point|object|collision|ctrl" || echo "(매칭 토픽 없음)"

  echo; echo "-- $EGO_TOPIC hz (6s) --"
  timeout 7 ros2 topic hz "$EGO_TOPIC" 2>&1 | head -4 || echo "(hz 실패/미수신)"

  echo; echo "-- $EGO_TOPIC echo --once --"
  timeout 8 ros2 topic echo --once "$EGO_TOPIC" 2>&1 | head -30 || echo "(echo 실패)"

  echo; echo "-- sim/wall offset (n=$COUNT, $EGO_TOPIC) --"
  timeout 40 python3 "$HERE/offset_probe.py" --topic "$EGO_TOPIC" --type "$EGO_TYPE" --count "$COUNT" 2>&1
} | tee "$LOG"

echo; echo "EVIDENCE=$LOG"
echo "민감정보 점검:"; grep -i -E "token|license|auth|password|key|secret" "$LOG" && echo "[!] 위 항목 확인 요" || echo "  (없음)"
