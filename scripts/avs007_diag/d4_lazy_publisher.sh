#!/usr/bin/env bash
# D4 — 구독자 가설 검증 (lazy publisher / "Autoware 부재" 반증)  [avs-007_layer_diagnosis.md §4.D4]
#
# 가설 H4: SIM publisher 는 구독자가 붙어야 발행을 시작한다 (lazy publisher).
# 변경점: 더미 구독자 1개(60초) 추가 — Autoware 의 구독자 역할을 1줄로 대체.
# 판정 (— "Autoware 부재" 질문의 최종 답):
#   - 구독자 유무와 무관하게 발행 없음 → H4 기각 → Autoware 부재와 무관, 벤더 귀속 확정
#   - 구독자 붙일 때만 발행 시작      → H4 채택 → 필요한 건 '임의의 구독자'(rosbag 이 충족).
#                                        Autoware 설치가 해법인 분기는 없음. 문서화 후 조건부 PASS
#
# 사용: d4_lazy_publisher.sh [토픽명=/Ego_topic]  (DOMAIN/RMW 는 D2 조합으로 export 후 실행)
set -uo pipefail

TOPIC="${1:-/Ego_topic}"
set +u; source /opt/ros/humble/setup.bash
[ -f "$HOME/avstack/ros2_ws/install/setup.bash" ] && source "$HOME/avstack/ros2_ws/install/setup.bash"
set -u
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

echo "== D4: lazy publisher 검증 ($TOPIC) =="

echo "-- 1. 더미 구독자 60초 유지 (백그라운드, best_effort) --"
( timeout -s KILL 60 ros2 topic echo "$TOPIC" --qos-reliability best_effort > /tmp/d4_sub.txt 2>&1 ) &
SUBPID=$!
sleep 5

echo "-- 2. 구독자 유지 상태에서 토픽/주파수 --"
timeout -s KILL 8 ros2 topic list 2>/dev/null | grep -iE "ego|morai" || echo "(목록에 없음)"
timeout -s KILL 16 ros2 topic hz "$TOPIC" 2>&1 | grep -iE "average rate|no new" | head -3 || true
DURING_RX=$(wc -l < /tmp/d4_sub.txt 2>/dev/null || echo 0)
echo "   구독자가 받은 라인 수(지금까지): $DURING_RX"

echo "-- 3. 구독자 종료 후 재확인 --"
kill "$SUBPID" 2>/dev/null || true; wait "$SUBPID" 2>/dev/null || true
sleep 2
timeout -s KILL 10 ros2 topic hz "$TOPIC" 2>&1 | grep -iE "average rate|no new" | head -2 || echo "(종료 후 발행 없음/측정 불가)"

echo; echo "== D4 판정 가이드 =="
if [ "${DURING_RX:-0}" -gt 0 ]; then
  echo "  → 구독자 부착 시 수신됨($DURING_RX 라인): H4 채택 — lazy publisher 특성."
  echo "    해법은 Autoware 가 아니라 '임의의 구독자'(rosbag record 가 상시 충족). 문서화 → 조건부 PASS."
  exit 0
else
  echo "  → 구독자 붙여도 발행 없음: H4 기각 — Autoware 부재와 무관. 벤더 귀속 확정."
  echo "    MORAI 문의에 'participant 유무(D1) + 구독자 부착에도 무발행(D4)' 첨부."
  exit 1
fi
