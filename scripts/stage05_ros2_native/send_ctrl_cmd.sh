#!/usr/bin/env bash
# Stage 05 (Gate 4) — ROS2 Native 제어 명령 단독 테스트.
# /ctrl_cmd_0 로 저속 velocity 명령을 보내 Ego 가 움직이는지 확인(Autoware 붙이기 전 송신 경로 검증).
# 선행: verify_topics.sh 로 /ego_vehicle_status 수신 확인 + SIM Ego Control 이 외부 명령 수신 모드.
# 주의: 실제로 차량을 움직이는 명령이다. SIM 상태 확인 후 사용.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"

CMD_TOPIC="${CMD_TOPIC:-/ctrl_cmd}"   # 실측: rosbridge 에 advertise 된 이름은 /ctrl_cmd
VEL="${VEL:-10.0}"
RATE="${RATE:-10}"

echo "[info] $CMD_TOPIC 로 velocity=$VEL km/h (longl_cmd_type=2) 를 ${RATE}Hz 로 송신. Ctrl+C 로 중지."
echo "[info] longl_cmd_type: 1=throttle, 2=velocity[km/h], 3=acceleration. front_steer=[rad]."
exec ros2 topic pub -r "$RATE" "$CMD_TOPIC" morai_msgs/msg/CtrlCmd \
  "{longl_cmd_type: 2, velocity: $VEL, accel: 0.0, brake: 0.0, front_steer: 0.0, rear_steer: 0.0}"
