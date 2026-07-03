#!/usr/bin/env bash
# Stage 05 공통 환경 — ROS2 Native 리스너 기준.
# 사용: source scripts/stage05_ros2_native/env.sh   (⚠ SIM 실행 셸에서는 절대 source 금지)
# MORAI SIM 26.R1(H3)은 ros2cs(ROS2ForUnity)를 내장하며 typesupport 가 전부 FastDDS 다.
# → 우리 리스너 RMW 은 반드시 rmw_fastrtps_cpp(기본)로 맞춰야 SIM 의 DDS 퍼블리시가 디스커버리된다.
#   (cyclonedds 로 바꾸면 RMW 불일치로 토픽이 안 보임. 근거: SIM Plugins fastrtps 303 / cyclone 0)
set +u   # ROS setup.bash 는 nounset 하에서 미정의 변수 참조
source /opt/ros/humble/setup.bash
WS="${AVSTACK_WS:-$HOME/avstack/ros2_ws}"
[ -f "$WS/install/setup.bash" ] && source "$WS/install/setup.bash"
set -u 2>/dev/null || true

export RMW_IMPLEMENTATION=rmw_fastrtps_cpp   # SIM 내장 ros2cs 와 동일 벤더(FastDDS)
export ROS_LOCALHOST_ONLY=0          # CLAUDE.md: 1 금지
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"   # SIM ROS2 설정의 Domain ID 와 일치해야 함

echo "[env] RMW=$RMW_IMPLEMENTATION DOMAIN=$ROS_DOMAIN_ID LOCALHOST_ONLY=$ROS_LOCALHOST_ONLY"
