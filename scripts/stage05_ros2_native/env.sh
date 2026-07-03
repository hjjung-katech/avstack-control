#!/usr/bin/env bash
# Stage 05 공통 환경 — ROS2 Native(CycloneDDS) 기준.
# 사용: source scripts/stage05_ros2_native/env.sh
# MORAI SIM 26.R1 은 ROS2 Humble 을 native 지원(rosbridge 불필요). RMW 을 CycloneDDS 로 맞춰야
# SIM 의 DDS 퍼블리시가 디스커버리된다(fastrtps 기본이면 토픽이 안 보임).
set +u   # ROS setup.bash 는 nounset 하에서 미정의 변수 참조
source /opt/ros/humble/setup.bash
WS="${AVSTACK_WS:-$HOME/avstack/ros2_ws}"
[ -f "$WS/install/setup.bash" ] && source "$WS/install/setup.bash"
set -u 2>/dev/null || true

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_LOCALHOST_ONLY=0          # CLAUDE.md: 1 금지
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"   # SIM ROS2 설정의 Domain ID 와 일치해야 함

echo "[env] RMW=$RMW_IMPLEMENTATION DOMAIN=$ROS_DOMAIN_ID LOCALHOST_ONLY=$ROS_LOCALHOST_ONLY"
