#!/usr/bin/env bash
# E3 관찰 — rosbridge 데이터 0 재검증 (MORAI-001 §3-B)
# 가설: rosbridge 경로는 연결·토픽 생성은 되나 header.seq 거부로 수신 데이터 0 (결정론적).
# 동일성 기준: 3회 모두 ① rosbridge 연결(client_count>0) ② 토픽 생성 ③ echo 수신 0건
#              ④ rosbridge_server 로그에 header/seq 거부 메시지.
# 사전: E2 와 분리(Native Connect 금지 — SIM 죽음). SIM 은 일반 모드로 살아있어야 함.
#
# 사용: e3_observe.sh <RUN> <start|observe|cleanup>
#   start   : 잔존 rosbridge/daemon 정리 → rosbridge_server 로깅 기동(background). 이후 사용자 GUI Connect.
#   observe : topic list + client_count + /Ego_topic echo 15s(0건 기대) + rosbridge 로그 seq 거부 카운트.
#   cleanup : rosbridge 종료 + daemon stop (회차 간 초기화).
set -uo pipefail

RUN="${1:?사용법: $0 <RUN> <start|observe|cleanup>}"
PHASE="${2:?사용법: $0 <RUN> <start|observe|cleanup>}"
DATE="${RECHECK_DATE:-20260706}"
BASE="$HOME/avstack/logs/avs007b_recheck_${DATE}_run${RUN}"
PIDF="${BASE}_rosbridge.pid"
RB="$HOME/avstack-control/scripts/stage05_ros2_native/run_rosbridge.sh"   # 실경로
ENVSH="$HOME/avstack-control/scripts/stage05_ros2_native/env.sh"

src() { set +u; source "$ENVSH" >/dev/null 2>&1; set -u; }

case "$PHASE" in
  start)
    echo "[E3 run${RUN} start] $(date -Is)"
    pkill -f rosbridge_websocket 2>/dev/null && echo "  잔존 rosbridge 종료" || true
    src; ros2 daemon stop >/dev/null 2>&1; echo "  daemon stop"
    echo "-- rosbridge_server 기동 → ${BASE}_rosbridge.log --"
    nohup bash "$RB" > "${BASE}_rosbridge.log" 2>&1 &
    echo $! > "$PIDF"; sleep 3
    grep -qi "rosbridge" "${BASE}_rosbridge.log" && echo "  rosbridge 기동됨(PID $(cat "$PIDF"))" || echo "  [주의] 기동 로그 미확인 — run_rosbridge.sh 확인"
    echo "이제 SIM Network Settings 에서 Simulator/Ego/Sensor 를 ROS 127.0.0.1:9090 으로 각각 Connect."
    ;;
  observe)
    echo "[E3 run${RUN} observe] $(date -Is)"; src
    ros2 daemon stop >/dev/null 2>&1; ros2 daemon start >/dev/null 2>&1
    echo "-- client_count --"; timeout -s KILL 5 ros2 topic echo --once /client_count 2>/dev/null | grep data || echo "  (미수신)"
    echo "-- topic list -t --"; timeout -s KILL 8 ros2 topic list -t 2>/dev/null | tee "${BASE}_topics.txt" | grep -iE "ego|gps|clock" || echo "  (MORAI 토픽 없음)"
    echo "-- /Ego_topic echo 15s (0건 기대) --"
    timeout -s KILL 16 ros2 topic echo /Ego_topic --qos-reliability best_effort > "${BASE}_echo.txt" 2>&1 || true
    RX=$(grep -cE "velocity|position|header|---" "${BASE}_echo.txt" 2>/dev/null || echo 0)
    echo "  echo 수신 라인: $RX  ($([ "$RX" -eq 0 ] && echo '0건 → 가설 부합' || echo '데이터 수신됨 — 재판단'))"
    echo "-- rosbridge 로그 header.seq 거부 카운트 --"
    SEQ=$(grep -cE "header.seq|does not have a field" "${BASE}_rosbridge.log" 2>/dev/null || echo 0)
    echo "  거부 메시지: $SEQ 개"; grep -m2 "does not have a field" "${BASE}_rosbridge.log" 2>/dev/null | sed 's/^/    /'
    ;;
  cleanup)
    echo "[E3 run${RUN} cleanup]"
    [ -f "$PIDF" ] && { kill "$(cat "$PIDF")" 2>/dev/null; rm -f "$PIDF"; }
    pkill -f rosbridge_websocket 2>/dev/null || true
    src; ros2 daemon stop >/dev/null 2>&1
    echo "  rosbridge 종료 + daemon stop 완료. (SIM 쪽은 Disconnect 해두세요.)"
    ;;
  *) echo "PHASE must be start|observe|cleanup" >&2; exit 2;;
esac
