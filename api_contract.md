# Scenario Runner Python API 계약 (실측)

Stage 03.5 산출물. `runbooks/integrated_roadmap.md` 4장 / `runbooks/stage03_5_checklist.md` 기준.
문서를 믿지 않고 **실제 동작을 실측**해 채운다. 실행 로그: `~/avstack/logs/sprint0_<timestamp>.log`.

> 상태: **TEMPLATE (미측정)** — 실험 실행 후 아래 `<...>` 자리를 실측값으로 채운다.

---

## 1. 환경 (버전)

| 항목 | 값 | 근거 |
|---|---|---|
| Scenario Runner 버전 | v1.7.0 (linux) | 설치 경로 `scenario_runner_v1.7.0_linux` |
| Simulator 버전 | `<get_simulator_version() 결과>` | 실측 |
| API 패키지 출처/버전 | `<OpenSCENARIO_API_*.zip (26.R1) 해제 경로>` | pip/GitHub 미제공, 계정 다운로드 |
| 암호 해제 런타임 | `<sourcedefender / pyconcrete + 버전>` | 암호화 lib 필수 의존 |
| grpcio / grpcio-tools | `<패키지 requirements 실측>` | 문서 1.39.0~1.44.0 릴리스별 상이 |
| Python | `<python3 --version>` | 암호화 lib 버전 잠금 주의(3.7.3? 3.10?) |
| Qt 바인딩 | `<PySide2 x.y / PyQt5 x.y / 미사용>` | 실측 |
| gRPC host:port | 127.0.0.1:7789 | Stage 03 관측 |
| API import 경로 | `API_MODULE=<...>  CLIENT_CLASS=<...>  API_SRC_DIR=<...>` | 스크립트 상단 확정값 |

## 2. Qt 의존성 판정

- Experiment 1 (QApplication 없이): `<PASS/FAIL, rc>`
- Experiment 2 (QCoreApplication): `<실행함/생략>` `<PASS/FAIL, rc>`
- **판정**: `<Qt 불필요 | Qt(이벤트 루프) 필요>`
- 판정이 "Qt 필요"인 경우 → **Adapter 프로세스 격리 설계 채택** (이유/설계 메모):
  `<메모>`

## 3. 함수별 실측 표

문서(help-morai-sim) 기준선은 아래와 같다. 실측으로 반환/예외를 채우고 불일치는 4장에 기록.
- 클래스: `OpenScenarioClientAPI`
- 생성자: `OpenScenarioClientAPI(host="127.0.0.1", port="7789", user_start_callback_func=None, user_stop_callback_func=None)` (port는 문자열)

| 함수 | 인자(문서) | 반환(실측) | 예외(실측) | 비고 |
|---|---|---|---|---|
| `OpenScenarioClientAPI(...)` | host, port, user_start_callback_func, user_stop_callback_func | `<...>` | `<...>` | port=str |
| `is_connected()` | — | `<...>` | `<...>` | |
| `get_simulator_version()` | — | `<...>` | `<...>` | |
| `get_available_map()` | — | `<...>` | `<...>` | |
| `set_scenario_config(...)` | `<문서 확인>` | `<...>` | `<...>` | 03.7에서 사용 |
| `start_batch_scenario()` | — | `<...>` | `<...>` | 03.7에서 사용 |

## 4. 문서-실동작 불일치 목록

문서/예제와 실제 시그니처·동작이 다른 항목을 기록한다 (설계노트 R14).

| 함수 | 문서 기준 | 실제 동작 | 대응 |
|---|---|---|---|
| `get_storyboard_element` (예) | `<문서 시그니처>` | `<실측>` | `<우회/래핑>` |
| `<...>` | `<...>` | `<...>` | `<...>` |

## 5. 경계 감지 후보 신호 관찰 메모 (Stage 03.7 준비)

Stage 03.7에서 확정할 시나리오 시작/종료 감지 신호의 사전 관찰을 적어둔다.

- S1. scenario name 변화: `<관찰>`
- S2. storyboard 상태 전이: `<관찰>`
- S3. sim time 리셋: `<관찰>`
- S4. eventlog/statelog 파일 생성 위치·명명 규칙: `<관찰>`
- S5. batch callback: `<관찰>`
- 잠정 결론(감지 조합 후보): `<메모>`

---

## 판정 요약

- Stage 03.5 PASS 기준: P1(연결)·P2(버전)·P3(Map) 성공 + P4(Qt 확정) + P5(본 문서 커밋).
- 현재: `<PASS / FAIL / 미측정>`
- 다음: Stage 03.7 (API 단일 실행 + 경계 감지, 게이트)
