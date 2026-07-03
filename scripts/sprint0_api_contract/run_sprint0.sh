#!/usr/bin/env bash
# Stage 03.5 / Sprint 0 — API 계약 검증 실행 러너.
# Experiment 1(no Qt)을 돌리고, 실패하면 Experiment 2(QCoreApplication)를 이어서 돌린다.
# 전체 출력을 ~/avstack/logs/sprint0_<timestamp>.log 로 tee 한다.
#
# 주의: 이 스크립트는 SIM+Scenario Runner가 이미 실행 중일 때 사용자가 직접 실행한다.
#       (Claude가 임의 실행하지 않는다.)
set -uo pipefail   # -e 아님: 종료코드를 직접 해석

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/avstack/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/sprint0_$(date +%Y%m%d_%H%M%S).log"

# API 클라이언트는 gRPC로 붙으므로 offload가 대개 무관하지만, 무해하므로 세팅.
export __NV_PRIME_RENDER_OFFLOAD=1
export __VK_LAYER_NV_optimus=NVIDIA_only
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# 이 API는 Python 3.7.3 전용(sourcedefender 잠금). 3.7 인터프리터를 우선 사용한다.
PY="${PYTHON:-python3.7}"
export MORAI_OSC_API="${MORAI_OSC_API:-$HOME/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3}"

{
  echo "==================================================================="
  echo " Sprint0 / Stage 03.5 — OpenSCENARIO API(22.R3) 계약 검증"
  echo "==================================================================="
  echo "[preflight] 실행 전 아래를 확인하라:"
  echo "  1) MORAI SIM 실행 중이고 지도 로드 완료 (scripts/run_morai_launcher_nvidia.sh)"
  echo "  2) Scenario Runner 실행 중 (SIM flow 경유), gRPC 포트 7789 대기"
  echo "  3) **Python 3.7.3 환경** — 암호화 lib이 3.7에 잠김. PYTHON 환경변수로 3.7 지정 가능."
  echo "  4) 의존성 설치됨: sourcedefender, PyQt5, numpy==1.19.1, grpcio, grpcio-tools 등"
  echo "  5) API 패키지 경로: MORAI_OSC_API=$MORAI_OSC_API"
  echo "  6) python=$PY"
  "$PY" --version 2>&1 | sed 's/^/       /' || echo "       [WARN] $PY 없음 — 3.7.3 venv 구성 후 PYTHON=<경로> 로 재실행"
  echo "[log] $LOG"
  echo

  echo "---- Experiment 1: 01_connect_no_qt.py ----"
  "$PY" "$HERE/01_connect_no_qt.py"
  rc1=$?
  echo "[rc] 01_connect_no_qt.py -> $rc1"

  if [ "$rc1" -ne 0 ]; then
    echo
    echo "---- Experiment 1 실패(rc=$rc1) → Experiment 2: 02_connect_qcore.py ----"
    "$PY" "$HERE/02_connect_qcore.py"
    rc2=$?
    echo "[rc] 02_connect_qcore.py -> $rc2"
  else
    echo "[skip] Experiment 1 성공 → Experiment 2 생략 (Qt 불필요 판정 근거)"
  fi

  echo
  echo "[next] 위 RESULT/EXCEPTION 라인을 저장소 루트 api_contract.md 에 옮겨 채운다."
  echo "       판정표는 runbooks/stage03_5_checklist.md 참조."
} 2>&1 | tee "$LOG"

echo "[done] log saved -> $LOG"
