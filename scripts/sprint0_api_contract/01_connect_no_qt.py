#!/usr/bin/env python3
"""Stage 03.5 / Sprint 0 — Experiment 1: Scenario Runner Python API WITHOUT QApplication.

integrated_roadmap.md 4장 참조. QApplication 이벤트 루프 없이 client를 생성하고
is_connected() -> get_simulator_version() -> get_available_map() 를 호출하여
각 결과/예외를 stdout에 구조화해 기록한다. 성공하면 "Qt 불필요" 판정 근거가 된다.

실행은 사용자가 SIM+Runner를 켠 상태에서 직접 한다 (run_sprint0.sh 경유).
"""
import sys
import traceback

# ============================================================================
# TODO(사용자 확정): API import 경로.
#   Stage 03.5 step1 결과 = 현재 설치본에 API 모듈이 동봉돼 있지 않음
#   (Scenario Runner는 PyInstaller 프리즈 바이너리만 존재).
#   MORAI에서 별도 배포되는 Scenario Runner Python API를 받은 뒤 아래를 채운다.
#     - 동봉 모듈형: API_SRC_DIR 에 모듈 폴더 경로 지정 (sys.path에 추가됨)
#     - pip 패키지형: 먼저 `pip install <패키지>`, API_SRC_DIR 은 빈 값 유지
#   API_MODULE / CLIENT_CLASS 는 실제 모듈명·클래스명으로 바꾼다.
# ----------------------------------------------------------------------------
API_SRC_DIR  = ""              # 예: "/home/hjjung/avstack/morai/scenario_runner_api"
API_MODULE   = "TODO_module"   # 예: "scenario_runner" / "morai" ...
CLIENT_CLASS = "TODO_Client"   # 예: "ScenarioRunner" / "Client" ...

# 연결 파라미터 (Stage 03에서 관측된 gRPC 포트 = 7789)
SR_HOST = "127.0.0.1"
SR_PORT = 7789

# 클라이언트 생성 방식도 문서 확인 후 확정한다. 아래 build_client()의 TODO 참조.
# ============================================================================


def log(tag, msg):
    print(f"[{tag}] {msg}", flush=True)


def not_configured():
    if API_MODULE == "TODO_module" or CLIENT_CLASS == "TODO_Client":
        log("ABORT", "API import 경로가 미확정(TODO). 상단 API_MODULE/CLIENT_CLASS를 "
                     "실제 값으로 채운 뒤 다시 실행하라. (step1: 설치본에 API 미동봉)")
        return True
    return False


def import_client():
    if API_SRC_DIR:
        sys.path.insert(0, API_SRC_DIR)
        log("INFO", f"sys.path += {API_SRC_DIR}")
    mod = __import__(API_MODULE, fromlist=[CLIENT_CLASS])
    cls = getattr(mod, CLIENT_CLASS)
    log("OK", f"import {API_MODULE}.{CLIENT_CLASS} = {cls}")
    return cls


def build_client(cls):
    # TODO(사용자 확정): 생성자 시그니처는 문서/예제로 확정.
    #   후보 A: cls(SR_HOST, SR_PORT)
    #   후보 B: c = cls(); c.connect(SR_HOST, SR_PORT)
    # 아래는 후보 A 기본값. 다르면 여기만 고친다.
    return cls(SR_HOST, SR_PORT)


def call(label, fn):
    """fn()을 실행하고 결과 또는 예외를 기록한다. 예외는 삼키고 계속 진행한다."""
    try:
        r = fn()
        log("RESULT", f"{label} -> {r!r}")
        return r
    except Exception as e:  # noqa: BLE001 — 계약 실측이 목적이므로 모든 예외 관찰
        log("EXCEPTION", f"{label} -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return None


def main():
    log("START", "Experiment 1 (no QApplication)")
    if not_configured():
        return 3
    try:
        cls = import_client()
    except Exception as e:  # noqa: BLE001
        log("EXCEPTION", f"import -> {type(e).__name__}: {e}")
        traceback.print_exc()
        return 2

    client = call("build_client", lambda: build_client(cls))
    if client is None:
        log("FAIL", "client 생성 실패 — 생성자 시그니처(build_client TODO) 확인 필요")
        return 1

    call("is_connected()", lambda: client.is_connected())
    call("get_simulator_version()", lambda: client.get_simulator_version())
    call("get_available_map()", lambda: client.get_available_map())

    log("DONE", "Experiment 1 완료 — 위 RESULT/EXCEPTION 라인을 api_contract.md에 옮긴다")
    return 0


if __name__ == "__main__":
    sys.exit(main())
