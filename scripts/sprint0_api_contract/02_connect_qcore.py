#!/usr/bin/env python3
"""Stage 03.5 / Sprint 0 — Experiment 2: Scenario Runner Python API WITH QCoreApplication.

Experiment 1(01_connect_no_qt.py)이 실패할 때만 실행한다. Qt 이벤트 루프가
필요한지 확인하기 위해 QCoreApplication을 띄운 상태에서 동일 호출을 반복한다.
성공하면 "Qt(이벤트 루프) 필요" 판정 → api_contract.md에 Adapter 프로세스 격리 설계 채택을 기록한다.

실행은 사용자가 SIM+Runner를 켠 상태에서 직접 한다 (run_sprint0.sh 경유).
"""
import sys
import traceback

# ============================================================================
# TODO(사용자 확정): 01_connect_no_qt.py 상단과 동일하게 채운다 (같은 값 사용).
# ----------------------------------------------------------------------------
API_SRC_DIR  = ""                        # 01과 동일 (다운로드한 SR API lib 폴더)
API_MODULE   = "TODO_module"             # 01과 동일 (모듈명 확정 필요)
CLIENT_CLASS = "OpenScenarioClientAPI"   # 01과 동일 (문서 확인됨)

SR_HOST = "127.0.0.1"
SR_PORT = 7789

# TODO(사용자 확정): Qt 바인딩. Scenario Runner 번들은 PySide2(Qt 5.15) 기반이므로
#   기본값 PySide2. 시스템에 PyQt5만 있으면 "PyQt5"로 바꾼다.
QT_BINDING = "PySide2"         # "PySide2" | "PyQt5"
# ============================================================================


def log(tag, msg):
    print(f"[{tag}] {msg}", flush=True)


def not_configured():
    if API_MODULE == "TODO_module" or CLIENT_CLASS == "TODO_Client":
        log("ABORT", "API import 경로가 미확정(TODO). 01과 동일하게 채운 뒤 실행하라.")
        return True
    return False


def import_qcore():
    if QT_BINDING == "PySide2":
        from PySide2.QtCore import QCoreApplication, QTimer
    elif QT_BINDING == "PyQt5":
        from PyQt5.QtCore import QCoreApplication, QTimer
    else:
        raise RuntimeError(f"알 수 없는 QT_BINDING={QT_BINDING!r}")
    log("OK", f"import {QT_BINDING}.QtCore.QCoreApplication")
    return QCoreApplication, QTimer


def import_client():
    if API_SRC_DIR:
        sys.path.insert(0, API_SRC_DIR)
        log("INFO", f"sys.path += {API_SRC_DIR}")
    mod = __import__(API_MODULE, fromlist=[CLIENT_CLASS])
    cls = getattr(mod, CLIENT_CLASS)
    log("OK", f"import {API_MODULE}.{CLIENT_CLASS} = {cls}")
    return cls


def build_client(cls):
    # 01_connect_no_qt.py와 동일: OpenScenarioClientAPI(host=, port="7789", ...). port는 문자열.
    return cls(host=SR_HOST, port=str(SR_PORT))


def call(label, fn):
    try:
        r = fn()
        log("RESULT", f"{label} -> {r!r}")
        return r
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"{label} -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return None


def run_experiment(cls):
    client = call("build_client", lambda: build_client(cls))
    if client is None:
        log("FAIL", "client 생성 실패 — 생성자 시그니처 확인 필요")
        return 1
    call("is_connected()", lambda: client.is_connected())
    call("get_simulator_version()", lambda: client.get_simulator_version())
    call("get_available_map()", lambda: client.get_available_map())
    return 0


def main():
    log("START", "Experiment 2 (QCoreApplication event loop)")
    if not_configured():
        return 3
    try:
        QCoreApplication, QTimer = import_qcore()
        cls = import_client()
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"import -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 2

    app = QCoreApplication(sys.argv)
    rc_box = {"rc": 1}

    def deferred():
        # 이벤트 루프가 살아있는 상태에서 API 호출 후 루프 종료
        try:
            rc_box["rc"] = run_experiment(cls)
        finally:
            app.quit()

    QTimer.singleShot(0, deferred)
    app.exec_()  # 이벤트 루프 진입 (PySide2/PyQt5 공통 exec_)
    log("DONE", f"Experiment 2 완료 rc={rc_box['rc']} — RESULT/EXCEPTION을 api_contract.md에 옮긴다")
    return rc_box["rc"]


if __name__ == "__main__":
    sys.exit(main())
