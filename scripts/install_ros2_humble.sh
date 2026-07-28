#!/usr/bin/env bash
# ROS2 Humble 설치 (wrx90, Stage 04 상당). 랩탑 t15p 구성 복제 + AVS-007(RMW 미설정) 반영.
# 정본 절차: runbooks/nw_ros2_humble_install.md
# 사용: bash scripts/install_ros2_humble.sh
#   - 내부에서 sudo 를 호출한다(암호 1회 입력, 이후 캐시). 재실행해도 안전(idempotent).
set -euo pipefail

echo "[1/5] 프리플라이트"
. /etc/os-release
if [ "${UBUNTU_CODENAME:-}" != "jammy" ]; then
  echo "  ERROR: Ubuntu 22.04(jammy)가 아님 → '$VERSION'. 중단."; exit 1
fi
command -v curl >/dev/null || sudo apt-get install -y curl
echo "  OK: $VERSION"

echo "[2/5] ROS2 apt 저장소 등록"
if [ ! -s /usr/share/keyrings/ros-archive-keyring.gpg ]; then
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "  키 설치됨"
else
  echo "  키 이미 있음(스킵)"
fi
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null
sudo apt-get update

echo "[3/5] ros-humble-desktop + 개발도구 설치 (수 분 소요)"
sudo apt-get install -y ros-humble-desktop \
  python3-colcon-common-extensions python3-rosdep python3-vcstool build-essential

echo "[4/5] rosdep 초기화"
sudo rosdep init 2>/dev/null || echo "  (이미 초기화됨 — 무시)"
rosdep update

echo "[5/5] 쉘 환경 (~/.bashrc)"
if ! grep -q 'ROS2 humble (avstack)' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<'RC'
# --- ROS2 humble (avstack) ---
source /opt/ros/humble/setup.bash
export ROS_LOCALHOST_ONLY=0                # CLAUDE.md: 1 금지
# RMW_IMPLEMENTATION 은 설정하지 않는다: humble 기본 rmw_fastrtps_cpp 로 충분하며,
# 명시 설정 자체가 MORAI SIM startup std::bad_cast 트리거(AVS-007). SIM 실행은 항상 래퍼로.
RC
  echo "  bashrc 에 추가함"
else
  echo "  bashrc 이미 설정됨(스킵)"
fi

echo
echo "===================================================================="
echo " 설치 완료. 검증하려면 새 터미널을 열거나:  source ~/.bashrc"
echo "   터미널 A:  ros2 run demo_nodes_cpp talker"
echo "   터미널 B:  ros2 topic echo /chatter --once   # 'Hello World: N' 수신 기대"
echo " (검증·증거 동결은 Claude가 대신 수행 가능 — 설치 끝나면 알려주세요)"
echo "===================================================================="
