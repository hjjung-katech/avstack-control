#!/usr/bin/env bash
# D2 — Domain ID / RMW 정합 검증  [avs-007_layer_diagnosis.md §4.D2]
#
# 가설 H2a: SIM 은 다른 Domain(예: UI 값)으로 발행 중 — Domain 불일치.
# 가설 H2b: SIM(FastDDS) ↔ 호스트 RMW 조합 문제로 상호발견 실패.
# 변경점: 조합당 환경변수(ROS_DOMAIN_ID, RMW_IMPLEMENTATION)만 — 세션 한정, 전역 불변.
# 판정:
#   - 어느 조합에서 MORAI 토픽(ego|morai|clock|vehicle) 출현 → 해당 조합 = 정답(환경 설정 귀속)
#     → env 변경은 ADR 로 별도 결정, d3 진행
#   - 전 조합 미출현(단 D1 PASS) → participant 는 있으나 publisher 없음(벤더 유력) → d4 1회 후 종료
# 중지 조건: 2×2 = 최대 4조합. 그 외 조합 탐색 금지.
#
# 사용: d2_domain_rmw.sh <SIM_UI_Domain값>   (예: 0)
# 정합 노트: 이 환경의 호스트 기준선 = DOMAIN 0 / rmw_fastrtps_cpp (env.sh).
set -uo pipefail

SIM_DOMAIN="${1:?사용법: $0 <SIM_UI_Domain값>  (SIM ROS2 설정 UI 에 표시된 값)}"

set +u; source /opt/ros/humble/setup.bash
[ -f "$HOME/avstack/ros2_ws/install/setup.bash" ] && source "$HOME/avstack/ros2_ws/install/setup.bash"
set -u
export ROS_LOCALHOST_ONLY=0

DOMAINS=(0)
[ "$SIM_DOMAIN" != "0" ] && DOMAINS+=("$SIM_DOMAIN")
RMWS=(rmw_fastrtps_cpp)
if [ -f /opt/ros/humble/lib/librmw_cyclonedds_cpp.so ]; then
  RMWS+=(rmw_cyclonedds_cpp)
else
  echo "[안내] rmw_cyclonedds 미설치 — cyclonedds 조합은 스킵. 원하면 직접: sudo apt install ros-humble-rmw-cyclonedds-cpp"
fi

echo "== D2: Domain × RMW 조합 스캔 (${DOMAINS[*]} × ${RMWS[*]}) =="
FOUND=""
for d in "${DOMAINS[@]}"; do
  for r in "${RMWS[@]}"; do
    tag="d${d}_${r#rmw_}"; out="/tmp/d2_${tag}.txt"
    echo; echo "-- 조합: DOMAIN=$d RMW=$r --"
    ros2 daemon stop >/dev/null 2>&1     # 캐시 배제 (조합마다)
    ROS_DOMAIN_ID="$d" RMW_IMPLEMENTATION="$r" timeout 10 ros2 topic list 2>/dev/null | tee "$out" || true
    hits=$(grep -icE "ego|morai|clock|vehicle|gps" "$out" 2>/dev/null || echo 0)
    echo "   → MORAI 후보 토픽: $hits 개 ($out)"
    [ "$hits" -gt 0 ] && FOUND="${FOUND}${FOUND:+, }(DOMAIN=$d,RMW=$r)"
  done
done
ros2 daemon stop >/dev/null 2>&1

echo; echo "== D2 판정 가이드 =="
if [ -n "$FOUND" ]; then
  echo "  → MORAI 토픽 출현 조합: $FOUND"
  echo "  → 환경 설정 귀속(H2a/H2b). env 표준 변경은 ADR 로. 다음: d3_qos_probe.sh /Ego_topic (해당 조합 env 로)"
  exit 0
else
  echo "  → 전 조합 미출현. D1 이 PASS 였다면 'participant 있으나 publisher 없음'(벤더 유력)."
  echo "  → 다음: d4_lazy_publisher.sh 를 1회만 확인 후 진단 종료."
  exit 1
fi
