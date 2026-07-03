#!/usr/bin/env python3.7
"""Stage 03.5 / Sprint 0 — Experiment 1: OpenSCENARIO API (22.R3) 연결 스모크, QApplication 없이.

실측 대상 = 실제 설치된 API 패키지의 `OpenScenarioClientWrapper`.
  경로: ~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3 (MORAI_OSC_API로 재지정 가능)
  ※ 문서(scenario-runner-kr)의 `OpenScenarioClientAPI` + is_connected/get_simulator_version/
     get_available_map 는 이 22.R3 패키지에 **존재하지 않는다**(문서-실물 불일치, api_contract.md 4장).

요구 사항 (중요):
  - **Python 3.7.3 전용** — lib이 sourcedefender로 암호화되어 파이썬 버전에 잠김. 3.7 아니면 import 실패.
  - 의존성: sourcedefender, PyQt5, numpy(1.19.1), grpcio/grpcio-tools 등.
  - 실행은 사용자가 SIM+Runner(gRPC 7789)를 켠 상태에서 run_sprint0.sh 경유로 직접 한다.

main.py 예제는 QApplication을 만들지 않고 QObject + busy-wait로 동작한다 → 본 실험(=QApplication 없음)이
문서화된 정상 경로다. 실패하면 02_connect_qcore.py(QApplication)로 넘어간다.
"""
import os
import sys
import traceback

# 실제 패키지 경로 (환경변수로 재지정 가능)
PKG_ROOT = os.environ.get(
    "MORAI_OSC_API",
    os.path.expanduser("~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3"),
)
# 연결 파라미터 (문서/예제: ip str, port str). SIM+Runner가 이 포트에서 대기해야 함.
SR_HOST = "127.0.0.1"
SR_PORT = "7789"


def log(tag, msg):
    print(f"[{tag}] {msg}", flush=True)


def check_py():
    v = sys.version_info
    log("INFO", f"python {v.major}.{v.minor}.{v.micro} @ {sys.executable}")
    if (v.major, v.minor) != (3, 7):
        log("WARN", "이 API는 Python 3.7.3 전용(sourcedefender 잠금). "
                    "3.7이 아니면 아래 import가 실패할 것이다 → 3.7.3 venv에서 재실행하라.")


def main():
    log("START", "Experiment 1 (no QApplication) — OpenScenarioClientWrapper")
    check_py()

    if not os.path.isdir(PKG_ROOT):
        log("ABORT", f"패키지 경로 없음: {PKG_ROOT} (MORAI_OSC_API로 재지정)")
        return 3
    sys.path.insert(0, PKG_ROOT)
    log("INFO", f"sys.path += {PKG_ROOT}")

    # sourcedefender: 암호화된 .pye lib을 로드 가능하게 하는 런타임. import 순서상 lib보다 먼저.
    try:
        import sourcedefender  # noqa: F401
        log("OK", "import sourcedefender")
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"import sourcedefender -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 2

    try:
        from open_scenario_importer_wrapper import OpenScenarioImporterWrapper  # noqa: F401
        from open_scenario_client_wrapper import OpenScenarioClientWrapper
        log("OK", "import OpenScenarioImporterWrapper, OpenScenarioClientWrapper")
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"import wrappers -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 2

    # 클라이언트 생성 (시나리오는 시작하지 않는다 — 계약 검증용 스모크).
    try:
        client = OpenScenarioClientWrapper(SR_HOST, SR_PORT)
        log("RESULT", f"OpenScenarioClientWrapper({SR_HOST!r}, {SR_PORT!r}) -> {client!r}")
        # get_stop_status(): 내부 client.is_start 반환 — 시작 전 초기값 관찰 (경계 감지 신호 후보)
        log("RESULT", f"get_stop_status() -> {client.get_stop_status()!r}")
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"client 생성/조회 -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 1

    log("DONE", "Experiment 1 완료 — QApplication 없이 생성 성공 여부를 api_contract.md에 기록")
    return 0


if __name__ == "__main__":
    sys.exit(main())
