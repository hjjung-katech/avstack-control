#!/usr/bin/env python3.7
"""Stage 03.5 / Sprint 0 — Experiment 2: OpenSCENARIO API (22.R3) 연결 스모크, QApplication 하에서.

Experiment 1(01_connect_no_qt.py)이 실패할 때만 실행한다. 실제 client(OpenScenarioClientWrapper)는
PyQt5 QObject이고 내부에서 QtWidgets를 import 하므로, 이벤트 루프가 필요한 경우를 대비해
**QApplication**(QCoreApplication 아님 — 위젯 심볼 때문) 하에서 동일 스모크를 반복한다.
성공하면 "Qt 이벤트 루프 필요" 판정 → api_contract.md에 Adapter 프로세스 격리 설계 채택을 기록.

요구: Python 3.7.3, sourcedefender, PyQt5. 실행은 사용자가 SIM+Runner 켠 상태에서 직접.
"""
import os
import sys
import traceback

PKG_ROOT = os.environ.get(
    "MORAI_OSC_API",
    os.path.expanduser("~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3"),
)
SR_HOST = "127.0.0.1"
SR_PORT = "7789"


def log(tag, msg):
    print(f"[{tag}] {msg}", flush=True)


def check_py():
    v = sys.version_info
    log("INFO", f"python {v.major}.{v.minor}.{v.micro} @ {sys.executable}")
    if (v.major, v.minor) != (3, 7):
        log("WARN", "이 API는 Python 3.7.3 전용(sourcedefender 잠금). 3.7 venv에서 실행하라.")


def run_smoke():
    """01과 동일한 import+생성 스모크. 이벤트 루프 안에서 호출된다."""
    import sourcedefender  # noqa: F401
    log("OK", "import sourcedefender")
    from open_scenario_importer_wrapper import OpenScenarioImporterWrapper  # noqa: F401
    from open_scenario_client_wrapper import OpenScenarioClientWrapper
    log("OK", "import wrappers")
    client = OpenScenarioClientWrapper(SR_HOST, SR_PORT)
    log("RESULT", f"OpenScenarioClientWrapper({SR_HOST!r}, {SR_PORT!r}) -> {client!r}")
    log("RESULT", f"get_stop_status() -> {client.get_stop_status()!r}")
    return 0


def main():
    log("START", "Experiment 2 (QApplication event loop) — OpenScenarioClientWrapper")
    check_py()

    if not os.path.isdir(PKG_ROOT):
        log("ABORT", f"패키지 경로 없음: {PKG_ROOT} (MORAI_OSC_API로 재지정)")
        return 3
    sys.path.insert(0, PKG_ROOT)
    log("INFO", f"sys.path += {PKG_ROOT}")

    try:
        from PyQt5.QtWidgets import QApplication
        from PyQt5.QtCore import QTimer
        log("OK", "import PyQt5 QApplication")
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"import PyQt5 -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 2

    app = QApplication(sys.argv)
    rc_box = {"rc": 1}

    def deferred():
        try:
            rc_box["rc"] = run_smoke()
        except Exception as e:  # noqa: BLE001
            log("EXCEPTION", f"smoke -> {type(e).__name__}: {e}")
            traceback.print_exc()
            rc_box["rc"] = 1
        finally:
            app.quit()

    QTimer.singleShot(0, deferred)
    app.exec_()
    log("DONE", f"Experiment 2 완료 rc={rc_box['rc']} — 결과를 api_contract.md에 기록")
    return rc_box["rc"]


if __name__ == "__main__":
    sys.exit(main())
