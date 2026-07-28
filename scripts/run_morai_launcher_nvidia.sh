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

# GPU 렌더 경로 (host-conditional):
#  - PRIME offload 변수는 하이브리드 호스트(렌더용 Intel/AMD iGPU가 기본 GL + NVIDIA discrete, 예: 랩탑 t15p)에서만 필요.
#  - NVIDIA가 주/단독 렌더러인 호스트(예: wrx90 RTX 5090; 디스플레이 컨트롤러=ASPEED BMC + NVIDIA만)에서는 미설정(전략 §7.4).
#  - prime-select는 두 호스트 모두 on-demand라 구분 불가(2026-07-28 실측) → 렌더용 iGPU 존재로 감지.
#  - 우선순위: 명시적 MORAI_PRIME_OFFLOAD(1/0) > 자동감지. ASPEED(BMC)는 렌더 iGPU가 아니므로 매칭 제외.
if [ -n "${MORAI_PRIME_OFFLOAD:-}" ]; then
  _offload="$MORAI_PRIME_OFFLOAD"
elif lspci 2>/dev/null | grep -iE 'VGA compatible controller|3D controller|Display controller' | grep -qiE 'intel|radeon|\[AMD/ATI\]'; then
  _offload=1
else
  _offload=0
fi
if [ "$_offload" = "1" ]; then
  export __NV_PRIME_RENDER_OFFLOAD=1
  export __VK_LAYER_NV_optimus=NVIDIA_only    # SIM은 Vulkan 렌더 (로그 확인)
  export __GLX_VENDOR_LIBRARY_NAME=nvidia      # 무해; GLX 폴백에만 사용
  echo "[INFO] PRIME offload 활성 (하이브리드 호스트)" >&2
else
  echo "[INFO] PRIME offload 비활성 (NVIDIA 주 렌더러) — offload 변수 미설정" >&2
fi

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
#  - 기본값 ON(2026-07-28): bashrc가 humble(fastrtps 2.6.11)을 소싱하므로, snap prefix(2.6.4)를 반드시
#    앞세워야 ROS2 Connect 크래시를 막는다. SOURCE_ROS2=0 으로 명시적 opt-out 가능(순수 렌더 전용).
if [ "${SOURCE_ROS2:-1}" = "1" ] && [ -f /opt/ros/humble/setup.bash ]; then
  set +u; source /opt/ros/humble/setup.bash; set -u
  if [ -n "${RMW_IMPLEMENTATION:-}" ]; then
    echo "[WARN] RMW_IMPLEMENTATION 설정됨(${RMW_IMPLEMENTATION}) — SIM startup 크래시 트리거(H4)라 해제함." >&2
    unset RMW_IMPLEMENTATION
  fi
  export ROS_LOCALHOST_ONLY=0
  # ROS2_OVERLAY=<ws/install 경로> 지정 시 오버레이(morai_ros2_msgs 등)를 추가 소싱.
  # 기본: ros2_ws_26r1/install 우선(존재 시), 없으면 ros2_ws/install.
  if [ -z "${ROS2_OVERLAY:-}" ]; then
    if [ -f "$HOME/avstack/ros2_ws_26r1/install/setup.bash" ]; then
      ROS2_OVERLAY="$HOME/avstack/ros2_ws_26r1/install"
    else
      ROS2_OVERLAY="$HOME/avstack/ros2_ws/install"
    fi
  fi
  if [ -f "$ROS2_OVERLAY/setup.bash" ]; then
    set +u; source "$ROS2_OVERLAY/setup.bash"; set -u
    echo "[INFO] ROS2 overlay 소싱 → $ROS2_OVERLAY" >&2
  fi
  # AVS-007 #2 (H1 반증됨, 2026-07-03 랩탑): fastdds 버전 정합(snap 2.6.4)은 크래시를 못 고친다.
  # 랩탑 N3 동작 레시피 = 순수 host humble + RMW 미설정(snap 없음). 따라서 FASTDDS_PREFIX 는
  # 기본 미적용(실험용 opt-in만). 명시 지정 시에만 앞세운다.
  if [ -n "${FASTDDS_PREFIX:-}" ] && [ -d "$FASTDDS_PREFIX/opt/ros/humble/lib" ]; then
    export LD_LIBRARY_PATH="$FASTDDS_PREFIX/opt/ros/humble/lib:${LD_LIBRARY_PATH:-}"
    echo "[INFO] (실험) FASTDDS_PREFIX 앞세움 → $FASTDDS_PREFIX" >&2
  fi
  # AVS-009 (2026-07-28 실측·양 호스트 재현): SIM 번들 libMORAI_V2X.so(정적 내장 C++,
  # GNU_UNIQUE 심볼 125개 — RTLD_LOCAL 이어도 프로세스 전역 유일)가 host libfastrtps 보다
  # 먼저 로드되면 나중에 로드된 fastrtps 가 V2X 의 구세대 unique 심볼에 바인딩되어
  # ROS2 Connect 시 DomainParticipantFactory 생성자에서 SIGSEGV.
  # SIM-free 재현: V2X 단독 dlopen→rclpy = crash / libfastrtps 선로드 후 V2X = 정상 (E1/E2).
  # → host libfastrtps 를 LD_PRELOAD 로 선로드해 심볼 바인딩 순서를 항상 고정한다.
  if [ -f /opt/ros/humble/lib/libfastrtps.so.2.6 ]; then
    export LD_PRELOAD="/opt/ros/humble/lib/libfastrtps.so.2.6${LD_PRELOAD:+:$LD_PRELOAD}"
    echo "[INFO] AVS-009 가드: host libfastrtps 선로드(LD_PRELOAD) — V2X unique-symbol 오염 차단" >&2
  fi
fi

MORAI_DIR="${MORAI_DIR:-$HOME/avstack/morai/launcher/MoraiLauncher_Lin}"
BIN="MoraiLauncher_Lin.x86_64"
LAUNCH_SH="MORAISim.sh"
USE_MORAISIM="${USE_MORAISIM:-1}"
LOG_DIR="$HOME/avstack/logs"
LOG_FILE="$LOG_DIR/MoraiLauncher_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"

# 검증용 env 덤프(런치 직전 실효 환경) — snap prefix/RMW 적용 여부를 사후 확인.
ENV_FILE="${LOG_FILE%.log}.env"
{
  echo "SOURCE_ROS2=${SOURCE_ROS2:-1}"
  echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-<unset>}"
  echo "FASTDDS_PREFIX=${FASTDDS_PREFIX:-<unset>}"
  echo "ROS2_OVERLAY=${ROS2_OVERLAY:-<unset>}"
  echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<unset>}"
  echo "LD_PRELOAD=${LD_PRELOAD:-<unset>}"
  echo -n "libfastrtps.so.2.6 해결="
  ldd_dir=""; IFS=':'; for d in ${LD_LIBRARY_PATH:-}; do
    if [ -e "$d/libfastrtps.so.2.6" ]; then ldd_dir="$(readlink -f "$d/libfastrtps.so.2.6")"; break; fi
  done; unset IFS
  echo "${ldd_dir:-<not found in LD_LIBRARY_PATH>}"
} > "$ENV_FILE" 2>/dev/null || true

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
