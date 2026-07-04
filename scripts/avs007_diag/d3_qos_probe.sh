#!/usr/bin/env bash
# D3 — QoS 착시 검증 (echo 침묵 판별)  [avs-007_layer_diagnosis.md §4.D3]
#
# 가설 H3: "미수신" 은 publisher QoS(best-effort 등) vs echo 기본값(reliable) 불일치 착시다.
# 전제: D2 까지에서 토픽이 목록에 보이는 상태.
# 변경점: echo 의 QoS 옵션만.
# 판정:
#   - QoS 맞추자 수신          → H3 확정(착시) → Stage05 판정 정정 + verify_topics.sh 에 QoS 반영
#   - QoS 맞춰도 침묵          → publisher 가 데이터를 안 쏨(벤더 유력) → d4 로
#
# 사용: d3_qos_probe.sh [토픽명=/Ego_topic]   (환경: DOMAIN/RMW 는 D2 에서 찾은 조합으로 export 후 실행)
set -uo pipefail

TOPIC="${1:-/Ego_topic}"
set +u; source /opt/ros/humble/setup.bash
[ -f "$HOME/avstack/ros2_ws/install/setup.bash" ] && source "$HOME/avstack/ros2_ws/install/setup.bash"
set -u
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

echo "== D3: QoS 프로브 ($TOPIC, RMW=$RMW_IMPLEMENTATION, DOMAIN=${ROS_DOMAIN_ID:-0}) =="

echo "-- 1. publisher 실제 QoS (가장 중요한 1줄) --"
timeout -s KILL 10 ros2 topic info -v "$TOPIC" 2>&1 | tee /tmp/d3_qos.txt | grep -iE "Publisher count|Reliability|Durability|History|Node name" || echo "(info 실패 — 토픽 존재부터 확인: D2)"

echo; echo "-- 2. publisher QoS 에 맞춘 echo --once (best_effort/volatile, 10s) --"
timeout -s KILL 12 ros2 topic echo "$TOPIC" --qos-reliability best_effort --qos-durability volatile --once 2>&1 | head -20 \
  && RXOK=1 || RXOK=0

echo; echo "-- 3. 주파수 실측 (15s) — 파이프라인 소스 자격 기초 데이터 --"
timeout -s KILL 16 ros2 topic hz "$TOPIC" 2>&1 | tee /tmp/d3_hz.txt | grep -iE "average rate|no new" | head -3 || true

echo; echo "== D3 판정 가이드 =="
if [ "${RXOK:-0}" = "1" ]; then
  echo "  → 수신됨: H3 확정(QoS 착시). Stage05 판정 정정 + verify_topics.sh 에 QoS 옵션 반영."
  exit 0
else
  echo "  → QoS 맞춰도 침묵: publisher 무발행(벤더 유력). 다음: d4_lazy_publisher.sh $TOPIC"
  exit 1
fi
