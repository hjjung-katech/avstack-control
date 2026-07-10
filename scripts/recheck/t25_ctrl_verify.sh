#!/usr/bin/env bash
# T-25 역방향 제어 판별 — 교란변수 분리: A.중력 drift / B.설정창 동결 / C.명령-움직임 시간 상관.
#   전제: SIM이 벤더 방식(N3: 소싱 후 직접 실행)으로 기동, ROS2 Connect 완료, 설정창 모두 닫힘.
#   모든 관측은 ${BASE}_track.log 에 [시각 label x y vx heading] 로 append — 명령 마커도 같은 로그에.
# 사용:
#   t25_ctrl_verify.sh <RUN> drift  [초=15]   # A: 무명령 관찰(창 닫힘)
#   t25_ctrl_verify.sh <RUN> freeze [초=10]   # B: 사용자 설정창 연 상태 관찰
#   t25_ctrl_verify.sh <RUN> mode   <16|1>    # auto(16)/keyboard(1) 전환 (제자리, 기어 D)
#   t25_ctrl_verify.sh <RUN> drive  [초=6] [km/h=10]   # C: 전진 명령+동시 샘플
#   t25_ctrl_verify.sh <RUN> stop   [초=3]    # C: 정지 명령+동시 샘플
set -uo pipefail
RUN="${1:?run id e.g. N3r2}"; PHASE="${2:?drift|freeze|mode|drive|stop}"
DATE="${T25_DATE:-20260710}"
BASE="$HOME/avstack/logs/avs007_t25_${DATE}_${RUN}"
WS="${AVSTACK_WS:-$HOME/avstack/ros2_ws}"

src() { set +u; source /opt/ros/humble/setup.bash; source "$WS/install/setup.bash"; set -u
        export ROS_LOCALHOST_ONLY=0; }
mark() { echo "$(date +%T.%3N) MARK $*" | tee -a "${BASE}_track.log"; }
sample() { # $1=label $2=초 — ~1Hz 위치/속도 샘플
  local label="$1" dur="$2" t0=$SECONDS
  while (( SECONDS - t0 < dur )); do
    local out; out=$(timeout -s KILL 4 ros2 topic echo /ego_vehicle_status --once --qos-reliability best_effort 2>/dev/null)
    local x y vx hd
    x=$(echo "$out"  | grep -A3 '^position:' | awk '/x:/{print $2; exit}')
    y=$(echo "$out"  | grep -A3 '^position:' | awk '/y:/{print $2; exit}')
    vx=$(echo "$out" | grep -A3 '^velocity:' | awk '/x:/{print $2; exit}')
    hd=$(echo "$out" | awk '/^heading:/{print $2; exit}')
    echo "$(date +%T.%3N) $label x=${x:-NA} y=${y:-NA} vx=${vx:-NA} heading=${hd:-NA}" | tee -a "${BASE}_track.log"
  done
}
src
case "$PHASE" in
  drift)  D="${3:-15}"; mark "drift 시작(무명령·창닫힘 ${D}s)"; sample drift "$D"; mark "drift 끝";;
  freeze) D="${3:-10}"; mark "freeze 시작(사용자 설정창 연 상태 ${D}s)"; sample freeze "$D"; mark "freeze 끝";;
  mode)
    M="${3:?16=auto|1=keyboard}"
    P=$(timeout -s KILL 6 ros2 topic echo /ego_vehicle_status --once --qos-reliability best_effort 2>/dev/null)
    PX=$(echo "$P" | grep -A3 '^position:' | awk '/x:/{print $2; exit}')
    PY=$(echo "$P" | grep -A3 '^position:' | awk '/y:/{print $2; exit}')
    PZ=$(echo "$P" | grep -A3 '^position:' | awk '/z:/{print $2; exit}')
    YW=$(echo "$P" | awk '/^heading:/{print $2; exit}')
    mark "mode=$M gear=4 발행(제자리 x=$PX y=$PY)"
    timeout -s KILL 4 ros2 topic pub --once /multi_ego_setting morai_ros2_msgs/msg/MultiEgoSetting \
      "{number_of_ego_vehicle: 1, camera_index: 0, ego_index: [0], global_position_x: [$PX], global_position_y: [$PY], global_position_z: [$PZ], global_roll: [0.0], global_pitch: [0.0], global_yaw: [$YW], velocity: [0.0], gear: [4], ctrl_mode: [$M]}" >/dev/null 2>&1
    ;;
  drive)
    D="${3:-6}"; V="${4:-10}"
    mark "drive 명령 시작(velocity=${V}km/h, ${D}s)"
    timeout -s KILL "$((D+1))" ros2 topic pub -r 10 /ctrl_cmd morai_ros2_msgs/msg/CtrlCmd \
      "{longl_cmd_type: 2, velocity: ${V}.0}" >/dev/null 2>&1 &
    sample drive "$D"; wait; mark "drive 명령 끝";;
  stop)
    D="${3:-3}"
    mark "stop 명령 시작(velocity=0, ${D}s)"
    timeout -s KILL "$((D+1))" ros2 topic pub -r 10 /ctrl_cmd morai_ros2_msgs/msg/CtrlCmd \
      '{longl_cmd_type: 2, velocity: 0.0}' >/dev/null 2>&1 &
    sample stop "$D"; wait; mark "stop 명령 끝";;
  *) echo "phase: drift|freeze|mode|drive|stop" >&2; exit 2;;
esac
