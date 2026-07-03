# Scenario Runner Python API 계약 (실측)

Stage 03.5 산출물. `runbooks/integrated_roadmap.md` 4장 / `runbooks/stage03_5_checklist.md` 기준.
문서를 믿지 않고 **실제 동작을 실측**해 채운다. 실행 로그: `~/avstack/logs/sprint0_<timestamp>.log`.

> 상태: **소스 확인 완료 / 런타임 실측 대기** — 아래 계약은 실제 패키지(22.R3) 예제 소스에서 확인.
> 런타임 반환/예외(`<...>`)는 Python 3.7.3 환경 구성 후 `run_sprint0.sh` 실행으로 채운다.

패키지: `~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3` (`OpenSCENARIO_API_22.R3.zip` 해제, Downloads에서 이동).

---

## 1. 환경 (버전)

| 항목 | 값 | 근거 |
|---|---|---|
| MORAI SIM(Drive) | 26.R1 | 설치본 |
| OpenSCENARIO API | **22.R3** (API 최신) | `OpenSCENARIO_API_22.R3` |
| Scenario Runner 번들 | v1.7.0 (linux) | `scenario_runner_v1.7.0_linux` |
| **필수 Python** | **3.7.3** | sourcedefender 암호화 lib 버전 잠금 (현재 시스템은 3.10 → 별도 venv 필요) |
| 암호 해제 런타임 | `sourcedefender` (main.py가 import) | 694개 `.pye` 암호화 파일 |
| GUI 의존성 | **PyQt5** (client가 QObject, QtWidgets import) | `open_scenario_client_wrapper.py` |
| 기타 의존성 | numpy(1.19.1), grpcio/grpcio-tools, scipy, matplotlib, eventhandler, pyproj | openscenario-api 문서 |
| gRPC | `morai_openscenario_base_pb2(_grpc)`, `morai_openscenario_msgs_pb2` (암호화 pb2) | `lib/openscenario/client` |
| gRPC host:port | 127.0.0.1:7789 (port는 문자열) | main.py / Stage 03 관측 |
| import 진입점 | 패키지 루트에서 `open_scenario_client_wrapper`, `open_scenario_importer_wrapper` | 예제 |

## 2. Qt 의존성 판정

- Experiment 1 (QApplication 없이): `<PASS/FAIL, rc>`
- Experiment 2 (QApplication): `<실행함/생략>` `<PASS/FAIL, rc>`
- **소스 근거**: `main.py`는 QApplication을 만들지 않고 `QObject` + `threading` + busy-wait로 동작
  → **잠정 판정: QApplication 이벤트 루프 불필요(단 PyQt5 QObject 심볼은 필요)**. Exp1로 최종 확정.
- 판정이 "Qt 루프 필요"로 뒤집히면 → **Adapter 프로세스 격리 설계 채택** 기록: `<메모>`

## 3. 함수별 실측 표 (소스 확인 = 문서 baseline)

**실물 클래스 (22.R3)** — 예제 wrapper:
- `OpenScenarioClientWrapper(ip: str, port: str)` — 내부에서 `OpenScenarioClient(ip, port, self)` 생성
- `OpenScenarioImporterWrapper()` — 내부에서 `OpenScenarioImporter()` 생성
- 하위: `from lib.openscenario.client.open_scenario_client import OpenScenarioClient`

| 함수 | 인자(소스) | 반환(실측) | 예외(실측) | 비고 |
|---|---|---|---|---|
| `OpenScenarioClientWrapper(ip, port)` | ip="127.0.0.1", port="7789" | `<...>` | `<...>` | port는 문자열 |
| `OpenScenarioImporterWrapper()` | — | `<...>` | `<...>` | |
| `importer.import_open_scenario(path)` | .xosc 절대경로 | `<...>` | `<...>` | MGeo 맵 로드 동반 |
| `client.set_open_scenario_importer(importer.scenario_importer)` | importer 인스턴스 | `<...>` | `<...>` | |
| `client.start_scenario()` | — | `<...>` | `<...>` | 03.7에서 사용 |
| `client.stop_scenario()` | — | `<...>` | `<...>` | 시나리오 종료 시 자동 호출 |
| `client.get_stop_status()` | — | `<bool>` | `<...>` | 내부 `client.is_start` — **경계 감지 신호** |

**실행 흐름(예제 main.py)**: `client_wrapper = OpenScenarioClientWrapper('127.0.0.1','7789')` →
(시나리오별) `importer_wrapper.import_open_scenario(abs_path)` →
`client_wrapper.set_open_scenario_importer(importer_wrapper.scenario_importer)` →
`client_wrapper.start_scenario()` → `while client_wrapper.get_stop_status(): time.sleep(1)`.

## 4. 문서-실동작 불일치 목록

| 항목 | 문서(scenario-runner-kr/python-api) | 실물(22.R3 패키지) | 대응 |
|---|---|---|---|
| 클라이언트 클래스 | `OpenScenarioClientAPI` | `OpenScenarioClientWrapper` (+ `OpenScenarioClient`) | 실물 wrapper 사용 |
| `is_connected()` | 있음 | **없음** | 연결 확인은 생성 성공/예외로 대체 |
| `get_simulator_version()` | 있음 | **없음** | 미제공 — 버전은 설치본으로 확인 |
| `get_available_map()` | 있음 | **없음** | Map은 `data/openscenario/*`로 확인 |
| `set_scenario_config()/start_batch_scenario()` | 있음 | **없음** (batch는 main.py 루프로 수동) | 03.7에서 파일 리스트 루프로 대체 |

> 두 문서 표면은 서로 다른 API 세대로 보인다. 26.R1 SIM에 붙는 실물은 **22.R3 wrapper** 계열.

## 5. 경계 감지 후보 신호 관찰 메모 (Stage 03.7 준비)

- **S. `get_stop_status()` 폴링** — 예제가 시나리오 종료 감지에 사용하는 1차 신호(`is_start` 플래그).
  종료 시 wrapper가 `stop_scenario()`를 자동 호출. → 03.7의 주 신호 후보.
- S4. eventlog/statelog 파일 생성 위치·명명: `<관찰>`
- S. scenario name/storyboard/sim-time: `<관찰>`
- 잠정 결론(감지 조합 후보): `<메모>`

---

## 판정 요약

- Stage 03.5 PASS 기준(재정의): (1) 3.7.3 환경에서 `sourcedefender`+wrapper import 성공,
  (2) `OpenScenarioClientWrapper('127.0.0.1','7789')` 생성 성공, (3) Qt 루프 필요 여부 확정,
  (4) 본 문서 커밋. (문서의 is_connected/version/map 스모크는 실물 부재로 대체.)
- 현재: `<PASS / FAIL / 미측정>`
- 다음: Stage 03.7 (API 단일 실행 + 경계 감지, 게이트) — `start_scenario()` + `get_stop_status()` 기반.
