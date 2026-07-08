#!/usr/bin/env bash
# T-24 관찰 — 벤더 진단(2026-07-08 "morai_msgs 미소싱") 검증: 2×2 매트릭스의 "소싱 후" 2셀.
#   소싱 전 셀 = 기존 실측(E2/E3, 2026-07-06 N=3)으로 갈음. 이 스크립트는 재사용 조건을 동일 유지:
#   SIM 26.R1.H3 / host Humble(fastrtps) / 런처 wrapper / 시그니처·D1 기준 = e2/e3_observe.sh 와 동일.
#   신규 조건 = morai msgs 26.R1 태그 빌드 오버레이(~/avstack/ros2_ws_26r1) 소싱.
#
# 셀 N2 (Native + 오버레이 소싱):
#   가설(벤더): 오버레이 소싱 시 startup std::bad_cast 미발생·연동 정상.
#   반증 기준(기존 실측과 동일): ① SIM 프로세스 소멸 ② Player.log std::bad_cast+librmw_fastrtps_cpp
#                                ③ RTPS 74xx 미바인딩(D1).
#   사용 절차:
#     터미널A: SOURCE_ROS2=1 ROS2_OVERLAY=$HOME/avstack/ros2_ws_26r1/install \
#              ~/avstack-control/scripts/run_morai_launcher_nvidia.sh
#     t24_observe.sh N2r<N> start   ← 런처 GUI 가 뜬 뒤 실행(런처 environ 캡처 = 소싱 증거)
#     [사용자] 지도 로드 → Start
#     t24_observe.sh N2r<N> finish  ← SIM 생존 시 topic list/echo 까지 자동 확인
#
# 셀 R2 (rosbridge + 26.R1 msgs):
#   가설(벤더): 26.R1 정합 msgs 소싱 시 데이터 수신.
#   반증 기준(기존과 동일): client_count>0·토픽 생성에도 echo 0 + rosbridge 로그 header.seq 거부.
#   사용 절차:
#     t24_observe.sh R2r<N> start    ← rosbridge(오버레이=26.R1) 기동
#     [사용자] SIM(일반 기동) Network Settings: Simulator/Ego/Sensor → ROS 127.0.0.1:9090 Connect
#     t24_observe.sh R2r<N> observe  ← client_count/topics/echo15s/hz/seq거부 카운트
#     t24_observe.sh R2r<N> ctrl     ← (수신 성공 시) CtrlCmd 역방향: 발행 5s, 사용자 SIM 육안 확인
#     t24_observe.sh R2r<N> cleanup
set -uo pipefail

RUN="${1:?사용법: $0 <N2r1|R2r1|...> <phase>}"
PHASE="${2:?phase: N2=start|finish, R2=start|observe|ctrl|cleanup}"
DATE="${T24_DATE:-20260708}"
BASE="$HOME/avstack/logs/avs007_t24_${DATE}_${RUN}"
OVERLAY="$HOME/avstack/ros2_ws_26r1"
PIDF_SS="${BASE}_ss.pid"; PIDF_RB="${BASE}_rosbridge.pid"

src26() { set +u; source /opt/ros/humble/setup.bash; source "$OVERLAY/install/setup.bash"
          export RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0 ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"; set -u; }

case "$PHASE" in
  start)
    echo "[T24 ${RUN} start] $(date -Is)"
    if [[ "$RUN" == N2* ]]; then
      # 런처 environ 캡처 — 이번엔 "소싱 여부"를 실물로 남긴다(기존 실측의 사각지대 해소)
      LPID=$(pgrep -f MoraiLauncher_Lin | head -1 || true)
      if [ -n "$LPID" ]; then
        tr '\0' '\n' < "/proc/$LPID/environ" | grep -E 'AMENT_PREFIX_PATH|LD_LIBRARY_PATH|RMW|ROS_' \
          > "${BASE}_launcher_environ.txt" 2>/dev/null
        grep -q "ros2_ws_26r1" "${BASE}_launcher_environ.txt" \
          && echo "  ✓ 런처 env 에 오버레이 확인(ros2_ws_26r1) → ${BASE}_launcher_environ.txt" \
          || echo "  [중단권고] 런처 env 에 오버레이 없음 — ROS2_OVERLAY 지정 후 런처 재기동 요망"
      else
        echo "  [중단권고] MoraiLauncher 미실행 — 먼저 SOURCE_ROS2=1 ROS2_OVERLAY=... 로 런처 기동"
      fi
      ps -eo pid,comm | awk '$2 ~ /^Simulator/{print $1}' | tee "${BASE}_simpid_before.txt"
      nohup bash -c 'while true; do ss -ulHpn 2>/dev/null | grep -E ":74[0-9][0-9] " | sed "s/^/$(date +%T.%N|cut -c1-11) /"; sleep 0.3; done' \
        > "${BASE}_ss.log" 2>&1 &
      echo $! > "$PIDF_SS"; sleep 1
      kill -0 "$(cat "$PIDF_SS")" 2>/dev/null && echo "  ss 폴러 실행 중(PID $(cat "$PIDF_SS"))" || echo "  [주의] 폴러 미기동"
      echo "이제 런처에서 지도 로드 → Start."
    else
      pkill -f rosbridge_websocket 2>/dev/null && echo "  잔존 rosbridge 종료" || true
      src26; ros2 daemon stop >/dev/null 2>&1
      echo "-- rosbridge_server 기동(오버레이=26.R1) → ${BASE}_rosbridge.log --"
      nohup env AVSTACK_WS="$OVERLAY" bash "$HOME/avstack-control/scripts/stage05_ros2_native/run_rosbridge.sh" \
        > "${BASE}_rosbridge.log" 2>&1 &
      echo $! > "$PIDF_RB"; sleep 3
      grep -qi rosbridge "${BASE}_rosbridge.log" && echo "  rosbridge 기동(PID $(cat "$PIDF_RB"))" || echo "  [주의] 기동 로그 미확인"
      # 오버레이·타입 증거
      ros2 interface show morai_msgs/msg/EgoVehicleStatus > "${BASE}_iface_ego.txt" 2>&1 \
        && echo "  ✓ morai_msgs 26.R1 타입 해석 확인 → ${BASE}_iface_ego.txt"
      echo "이제 SIM Network Settings: Simulator/Ego/Sensor → ROS 127.0.0.1:9090 Connect."
    fi
    ;;
  finish)   # N2 전용
    echo "[T24 ${RUN} finish] $(date -Is)"
    ps -eo pid,comm | awk '$2 ~ /^Simulator/{print $1" "$2}' | tee "${BASE}_simpid_after.txt"
    [ -f "$PIDF_SS" ] && { kill "$(cat "$PIDF_SS")" 2>/dev/null; rm -f "$PIDF_SS"; }
    PL=$(find "$HOME/.config/unity3d/MORAI" -name "Player.log" 2>/dev/null | head -1)
    [ -n "$PL" ] && cp "$PL" "${BASE}_player.log" && echo "  Player.log → ${BASE}_player.log"
    echo "-- 시그니처(std::bad_cast/librmw) --"
    grep -nE "std::bad_cast|librmw_fastrtps_cpp|NativeRcl" "${BASE}_player.log" 2>/dev/null | head -5 || echo "  (시그니처 없음 ← 기존과 다름!)"
    echo "-- D1: RTPS 74xx 바인딩 --"
    SIMBIND=$(grep -ciE "Simulator" "${BASE}_ss.log" 2>/dev/null || echo 0)
    echo "  Simulator 소유 74xx 라인: $SIMBIND $([ "$SIMBIND" -gt 0 ] && echo '← participant 생성! 기존 D1=FAIL 과 다름' || echo '(기존과 동일: 미바인딩)')"
    if [ -s "${BASE}_simpid_after.txt" ]; then
      echo "-- SIM 생존 → native 토픽 확인 --"; src26
      ros2 daemon stop >/dev/null 2>&1; ros2 daemon start >/dev/null 2>&1
      timeout -s KILL 8 ros2 topic list -t 2>/dev/null | tee "${BASE}_topics.txt" | grep -iE "ego|morai|gps" || echo "  (MORAI 토픽 없음)"
      timeout -s KILL 16 ros2 topic echo /Ego_topic --qos-reliability best_effort > "${BASE}_echo.txt" 2>&1 || true
      N=$(grep -c "^---" "${BASE}_echo.txt" 2>/dev/null || echo 0); echo "  /Ego_topic 15s 수신: ${N}건"
    fi
    echo "-- 증거 --"; ls -1 "${BASE}"_* 2>/dev/null | sed 's#.*/#  #'
    ;;
  observe)  # R2 전용
    echo "[T24 ${RUN} observe] $(date -Is)"; src26
    ros2 daemon stop >/dev/null 2>&1; ros2 daemon start >/dev/null 2>&1
    echo "-- client_count --"; timeout -s KILL 5 ros2 topic echo --once /client_count 2>/dev/null | grep data || echo "  (미수신)"
    echo "-- topic list --"; timeout -s KILL 8 ros2 topic list -t 2>/dev/null | tee "${BASE}_topics.txt" | grep -icE "." | xargs echo "  토픽 수:"
    echo "-- /Ego_topic echo 15s --"
    timeout -s KILL 16 ros2 topic echo /Ego_topic --qos-reliability best_effort > "${BASE}_echo.txt" 2>&1 || true
    N=$(grep -c "^---" "${BASE}_echo.txt" 2>/dev/null || echo 0); echo "  수신: ${N}건 $([ "$N" -gt 0 ] && echo '← 데이터 흐름! 기존 0건과 다름' || echo '(기존과 동일: 0건)')"
    [ "$N" -gt 0 ] && { timeout -s KILL 12 ros2 topic hz /Ego_topic > "${BASE}_hz.txt" 2>&1 || true; grep -m2 "average rate" "${BASE}_hz.txt" || true; }
    echo "-- rosbridge seq 거부 카운트 --"
    C=$(grep -c "does not have a field" "${BASE}_rosbridge.log" 2>/dev/null || echo 0)
    echo "  거부 로그: ${C}건"; grep -m2 "does not have a field" "${BASE}_rosbridge.log" 2>/dev/null || true
    ;;
  ctrl)     # R2 전용 — 역방향 제어 (사용자 SIM 육안 확인 필요)
    echo "[T24 ${RUN} ctrl] $(date -Is) — CtrlCmd 5s 발행(accel 0.3). SIM 에서 Ego 반응 육안 확인 요망."; src26
    timeout -s KILL 6 ros2 topic pub -r 10 /ctrl_cmd morai_msgs/msg/CtrlCmd \
      '{longl_cmd_type: 1, accel: 0.3, brake: 0.0, front_steer: 0.0}' > "${BASE}_ctrlpub.txt" 2>&1 || true
    tail -2 "${BASE}_ctrlpub.txt"; echo "  → [사용자] 차량 가속 여부를 보고해 주세요(관측 결과는 기록에 수기 반영)."
    ;;
  cleanup)  # R2 전용
    echo "[T24 ${RUN} cleanup] $(date -Is)"
    [ -f "$PIDF_RB" ] && { kill "$(cat "$PIDF_RB")" 2>/dev/null; rm -f "$PIDF_RB"; }
    pkill -f rosbridge_websocket 2>/dev/null || true
    src26; ros2 daemon stop >/dev/null 2>&1; echo "  정리 완료"
    ;;
  *) echo "phase 오류: N2=start|finish, R2=start|observe|ctrl|cleanup" >&2; exit 2;;
esac
