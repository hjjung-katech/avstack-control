#!/usr/bin/env bash
# AVS-007 계층 진단 — 사전 조건 체크리스트 (runbooks/avs-007_layer_diagnosis.md §3)
# 시스템 상태를 바꾸지 않는다(관찰만). 각 항목 [OK]/[FAIL]/[TODO]로 출력.
set -uo pipefail

pass=0; fail=0
ok()   { echo "  [OK]   $1"; pass=$((pass+1)); }
bad()  { echo "  [FAIL] $1"; fail=$((fail+1)); }
todo() { echo "  [TODO] $1"; }

echo "== AVS-007 진단 preflight ($(date +%F' '%T)) =="

echo "-- 1. MORAI SIM 실행 중 + 지도 로드 --"
SIMPID=$(ps -eo pid,comm | awk '$2 ~ /^Simulator/{print $1; exit}')
LNCPID=$(ps -eo pid,comm | awk '$2 ~ /^MoraiLauncher/{print $1; exit}')
[ -n "${SIMPID:-}" ] && ok "Simulator 프로세스: PID $SIMPID" || bad "Simulator 프로세스 없음 (런처에서 Start + 지도 로드 필요; 런처: ${LNCPID:-없음})"
command -v nvidia-smi >/dev/null && nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader 2>/dev/null | grep -q . \
  && ok "nvidia-smi 에 GPU 프로세스 있음" || todo "nvidia-smi GPU 프로세스 확인(수동)"

echo "-- 2. SIM ROS2 UI 스크린샷 + Domain ID 기록 --"
[ -f "$HOME/avstack/logs/avs007_sim_ros2_ui.png" ] && ok "UI 스크린샷 존재" || todo "SIM ROS2 설정 화면 스크린샷 → ~/avstack/logs/avs007_sim_ros2_ui.png"
todo "SIM UI 의 Domain ID 값을 기록해라 (D2 인자로 사용) — 기본 추정 0"

echo "-- 3. 호스트 ROS2 환경 (정합 노트: env.sh = DOMAIN 0 / fastrtps) --"
if [ -f "$HOME/avstack-control/scripts/stage05_ros2_native/env.sh" ]; then
  ok "env.sh 존재 (source scripts/stage05_ros2_native/env.sh)"
else
  bad "env.sh 없음"
fi
[ -f /opt/ros/humble/lib/librmw_fastrtps_cpp.so ] && ok "rmw_fastrtps 설치됨" || bad "rmw_fastrtps 없음 → 설치 안내: sudo apt install ros-humble-rmw-fastrtps-cpp (직접 실행)"
[ -f /opt/ros/humble/lib/librmw_cyclonedds_cpp.so ] && ok "rmw_cyclonedds 설치됨 (D2 교차검증용)" || todo "rmw_cyclonedds 없음 — D2 의 cyclonedds 조합은 스킵됨. 원하면: sudo apt install ros-humble-rmw-cyclonedds-cpp"
command -v tcpdump >/dev/null && ok "tcpdump 있음 (D1, sudo 필요)" || bad "tcpdump 없음 → 설치 안내: sudo apt install tcpdump (직접 실행)"

echo "-- 4. rosbridge/브리지 프로세스 전부 종료 (D1~D4 는 Native 만 본다) --"
RB=$(pgrep -af rosbridge | grep -v pgrep || true)
if [ -n "$RB" ]; then bad "rosbridge 잔존 → 종료 필요: $RB"; else ok "rosbridge 프로세스 없음"; fi
TALKER=$(pgrep -af "demo_nodes\|talker" | grep -v pgrep || true)
[ -n "$TALKER" ] && bad "talker/demo 잔존 → 종료 필요: $TALKER" || ok "talker/demo 잔존 없음"

echo "-- 5. 원본 로그 --"
todo "진단 시작 전 별도 터미널에서: script -af ~/avstack/runs/avs007_diag_\$(date +%Y%m%d_%H%M%S).log"

echo
echo "== 결과: OK $pass / FAIL $fail =="
[ "$fail" -eq 0 ] && echo "→ 진단 진행 가능 (run_all_diag.sh 또는 d1부터)" || echo "→ FAIL 항목 해소 후 재실행"
exit "$fail"
