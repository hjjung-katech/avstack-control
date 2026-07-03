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

PY="${PYTHON:-python3}"

{
  echo "==================================================================="
  echo " Sprint0 / Stage 03.5 — Scenario Runner Python API 계약 검증"
  echo "==================================================================="
  echo "[preflight] 실행 전 아래를 확인하라:"
  echo "  1) MORAI SIM 실행 중이고 지도 로드 완료"
  echo "     (scripts/run_morai_launcher_nvidia.sh 로 기동)"
  echo "  2) Scenario Runner 실행 중 (SIM flow 경유), gRPC 포트 7789 대기"
  echo "  3) 01/02 스크립트 상단 TODO(import 경로: API_MODULE/CLIENT_CLASS/API_SRC_DIR) 확정 완료"
  echo "     — step1 확인: 현재 설치본엔 API 미동봉. 별도 API 패키지 확보 후 채울 것."
  echo "  4) python=$PY"
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
