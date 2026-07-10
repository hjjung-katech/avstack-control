#!/usr/bin/env bash
# MORAI Launcher/SIM 실행 (NVIDIA PRIME offload).
# 공식 매뉴얼: https://morai-sim--drive-user-manual--en-22-r2.scrollhelp.site/msdume2/installation-and-setup
#   $ chmod +x MORAISim.sh && chmod +x MoraiLauncher_Lin.x86_64 && ./MORAISim.sh
#
# 실측으로 밝혀진 동작 (runbook 10.2 참조):
#  - MORAISim.sh는 런처를 백틱으로 실행 → 런처 stdout 'Found path:'를 명령 실행 → 항상 exit 127
#    (스크립트 버그, 런처 실행 자체는 정상). 이 래퍼가 127을 흡수한다.
#  - 런처는 SingleInstance 모드다. 살아있는 인스턴스가 있으면 새 실행은 창 없이 양보-exit0.
#    → 실행 전 기존 인스턴스를 가드한다.
#  - unity.lock은 정상 종료해도 남지만, PID가 죽은 stale lock은 다음 실행이 자동 인수한다.
#  - '정상 종료'는 종료코드가 아니라 창 표시 + Player.log로 판단한다.
#
# 토글:
#  USE_MORAISIM=1 (기본) 공식 MORAISim.sh 경유 / =0 런처 바이너리 직접 실행(깨끗한 종료코드)
#  RUN_REMOTE=1  SSH→NoMachine: DISPLAY=:1, XAUTHORITY=~/.Xauthority 자동 설정 (18.6)
set -uo pipefail   # -e 아님: 종료코드를 직접 해석하기 위해

export __NV_PRIME_RENDER_OFFLOAD=1
export __VK_LAYER_NV_optimus=NVIDIA_only    # SIM은 Vulkan 렌더 (로그 확인)
export __GLX_VENDOR_LIBRARY_NAME=nvidia      # 무해; GLX 폴백에만 사용

if [ "${RUN_REMOTE:-0}" = "1" ]; then
  export DISPLAY="${DISPLAY:-:1}"
  export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
fi

# ROS2 소싱: SOURCE_ROS2=1 로 켠다 (AVS-007 해결 — T-25/H4, 2026-07-10 실측).
#  - SIM startup `std::bad_cast` 의 트리거는 소싱 자체가 아니라 `RMW_IMPLEMENTATION` 환경변수였다:
#    설정 시 rcl 의 rmw identifier 검사(rmw_implementation_identifier_check.c)가 열리고 그 경로의
#    dlopen 에서 std::bad_cast → SIM 즉시 종료(N4 실측). 미설정 시 검사 생략 → 정상(N3 실측).
#  - 따라서 이 블록은 RMW_IMPLEMENTATION 을 설정하지 않으며, 이미 설정돼 있으면 해제한다.
#  - 동작 레시피(N3): humble + morai msgs ws 소싱 → SIM GUI 에서 ROS2 Connect → 수신 50Hz·제어 동작.
#    주의: SIM 설정창(센서 등)이 열려 있는 동안 물리 일시정지(토픽은 마지막 값 반복) — T-25 B 실측.
if [ "${SOURCE_ROS2:-0}" = "1" ] && [ -f /opt/ros/humble/setup.bash ]; then
  set +u; source /opt/ros/humble/setup.bash; set -u
  if [ -n "${RMW_IMPLEMENTATION:-}" ]; then
    echo "[WARN] RMW_IMPLEMENTATION 설정됨(${RMW_IMPLEMENTATION}) — SIM startup 크래시 트리거(H4)라 해제함." >&2
    unset RMW_IMPLEMENTATION
  fi
  export ROS_LOCALHOST_ONLY=0
  # ROS2_OVERLAY=<ws/install 경로> 지정 시 오버레이(morai_ros2_msgs 등)를 추가 소싱 (기본: ~/avstack/ros2_ws).
  ROS2_OVERLAY="${ROS2_OVERLAY:-$HOME/avstack/ros2_ws/install}"
  if [ -f "$ROS2_OVERLAY/setup.bash" ]; then
    set +u; source "$ROS2_OVERLAY/setup.bash"; set -u
    echo "[INFO] ROS2 overlay 소싱 → $ROS2_OVERLAY" >&2
  fi
  # AVS-007 #2: FASTDDS_PREFIX 를 앞세워 SIM 만 SIM-빌드시점(2023) Fast-DDS 를 쓰게 함
  # (시스템 /opt/ros/humble 은 그대로, LD_LIBRARY_PATH 우선순위로 libfastrtps 등만 오버라이드).
  if [ -n "${FASTDDS_PREFIX:-}" ] && [ -d "$FASTDDS_PREFIX/opt/ros/humble/lib" ]; then
    export LD_LIBRARY_PATH="$FASTDDS_PREFIX/opt/ros/humble/lib:${LD_LIBRARY_PATH:-}"
    echo "[INFO] AVS-007 #2: fastdds prefix 앞세움 → $FASTDDS_PREFIX"
  fi
fi

MORAI_DIR="${MORAI_DIR:-$HOME/avstack/morai/launcher/MoraiLauncher_Lin}"
BIN="MoraiLauncher_Lin.x86_64"
LAUNCH_SH="MORAISim.sh"
USE_MORAISIM="${USE_MORAISIM:-1}"
LOG_DIR="$HOME/avstack/logs"
LOG_FILE="$LOG_DIR/MoraiLauncher_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"

# 가드: 살아있는 런처가 있으면 새 실행은 창 없이 양보(exit0)하므로 막는다.
if pgrep -f "$BIN" >/dev/null 2>&1; then
  echo "[ERROR] MoraiLauncher가 이미 실행 중이다. 먼저 닫아라." >&2
  echo "        (SingleInstance: 두 번째 실행은 창 없이 양보하고 exit 0으로 끝난다)" >&2
  exit 1
fi
# stale unity.lock(죽은 PID) 안내 — 런처가 자동 인수하므로 정보만 출력.
LOCK="$MORAI_DIR/unity.lock"
if [ -f "$LOCK" ]; then
  lpid="$(tr -dc '0-9' < "$LOCK" 2>/dev/null)"
  if [ -n "${lpid:-}" ] && ! kill -0 "$lpid" 2>/dev/null; then
    echo "[INFO] stale unity.lock (죽은 PID $lpid) — 런처가 인수한다."
  fi
fi

cd "$MORAI_DIR"
echo "[INFO] MORAI_DIR=$MORAI_DIR  USE_MORAISIM=$USE_MORAISIM  DISPLAY=${DISPLAY:-(inherited)}"
echo "[INFO] LOG_FILE=$LOG_FILE"

if [ "$USE_MORAISIM" = "1" ]; then
  [ -f "$LAUNCH_SH" ] || { echo "[ERROR] $MORAI_DIR/$LAUNCH_SH not found" >&2; exit 1; }
  chmod +x "$LAUNCH_SH" "$BIN" 2>/dev/null || true
  echo "[INFO] 공식 실행: ./$LAUNCH_SH"
  ./"$LAUNCH_SH" 2>&1 | tee "$LOG_FILE"
  rc=${PIPESTATUS[0]}
  if [ "$rc" -eq 127 ]; then
    echo "[WARN] MORAISim.sh exit 127 — 알려진 백틱 quirk. 런처 실행엔 영향 없음." >&2
    echo "       성공 판단은 창 표시 + ~/.config/unity3d/MORAI/Simulator/Player.log 로." >&2
    rc=0
  fi
else
  [ -f "$BIN" ] || { echo "[ERROR] $MORAI_DIR/$BIN not found" >&2; exit 1; }
  chmod +x "$BIN" 2>/dev/null || true
  echo "[INFO] 직접 실행: ./$BIN  (깨끗한 종료코드)"
  ./"$BIN" 2>&1 | tee "$LOG_FILE"
  rc=${PIPESTATUS[0]}
  echo "[INFO] 런처 종료코드: $rc (0=정상 닫기. 단 살아있는 2번째 인스턴스면 양보로도 0)"
fi
exit "$rc"
