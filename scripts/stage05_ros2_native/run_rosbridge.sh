#!/usr/bin/env bash
# Stage 05 — rosbridge_server(websocket, 9090) 실행.
# MORAI SIM(RosBridgeClient)이 이 서버에 접속하면 토픽이 ROS2 DDS로 노출된다.
# 선행: ros-humble-rosbridge-suite 설치(sudo), morai_ros2_msgs colcon 빌드(~/avstack/ros2_ws).
set -euo pipefail

WS="${AVSTACK_WS:-$HOME/avstack/ros2_ws}"
PORT="${ROSBRIDGE_PORT:-9090}"

source /opt/ros/humble/setup.bash
[ -f "$WS/install/setup.bash" ] && source "$WS/install/setup.bash" || \
  echo "[WARN] $WS/install/setup.bash 없음 — morai_ros2_msgs 미빌드? (토픽은 뜨나 타입 미해석 가능)"
export ROS_LOCALHOST_ONLY=0   # CLAUDE.md: 1 금지

if ! ros2 pkg prefix rosbridge_server >/dev/null 2>&1; then
  echo "[ERROR] rosbridge_server 미설치. 먼저: sudo apt install -y ros-humble-rosbridge-suite" >&2
  exit 3
fi

echo "[INFO] rosbridge_websocket 시작 (port=$PORT). SIM Network Settings의 Bridge IP=127.0.0.1, 포트 일치 확인."
exec ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:="$PORT"
