#!/usr/bin/env bash
# Stage 05 [AVS-007 백업 경로] — rosbridge_server(websocket 9090).
# ROS2 Native(ros2cs)가 AVS-007(ABI)로 막혔을 때의 우회. SIM 의 RosBridgeClient(WebSocket)는
# ros2cs/DDS ABI 를 타지 않으므로 이 블로커와 무관하게 동작한다.
#
# 구성:
#   host:  이 스크립트로 rosbridge_server 실행(host ROS2=fastrtps).
#   SIM :  일반 실행(scripts/run_morai_launcher_nvidia.sh, ROS2 미소싱). Network Settings 를
#          **ROS(bridge)** 로 두고 Bridge IP=127.0.0.1, Port=9090, Connect. (ROS2 Native 아님)
#   확인:  별도 터미널에서 verify_topics.sh (host 가 재발행한 DDS 토픽을 봄).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"          # host ROS2 humble + ws + fastrtps
PORT="${ROSBRIDGE_PORT:-9090}"

if ! ros2 pkg prefix rosbridge_server >/dev/null 2>&1; then
  echo "[ERROR] rosbridge_server 미설치. 먼저: sudo apt install -y ros-humble-rosbridge-suite" >&2
  exit 3
fi
echo "[INFO] rosbridge_websocket 시작 (port=$PORT). SIM Network Settings=ROS(bridge), Bridge IP=127.0.0.1, 포트 일치."
exec ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:="$PORT"
