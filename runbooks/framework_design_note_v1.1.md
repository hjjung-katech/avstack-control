# MORAI SIM 기반 자동화 평가 Framework 설계 노트 v1.1

| 항목 | 내용 |
|---|---|
| 문서명 | MORAI SIM 기반 자동화 평가 Framework 설계 노트 |
| 버전 | v1.1 |
| 작성일 | 2026-07-03 (v1.0: 2026-07-02) |
| 대상 | MORAI SIM 26.R1, Scenario Runner, ROS2, 향후 Autoware 연동 |
| 문서 성격 | PM + 구현 엔지니어 관점의 아키텍처/검증/로드맵 설계 문서 |
| 1차 목표 | Built-in 기반 시나리오 자동 실행·로깅·평가 체계 수립 |
| 최종 목표 | 재현 가능한 Scenario Validation Automation Framework 구축 |

---

## v1.1 변경 이력 (Change Log)

공식 문서(Scenario Runner Python API, SIM Drive 26.R1) 재대조 및 구현 관점 검토 결과를 반영한다.

| # | 구분 | 변경 내용 | 관련 절 |
|---|---|---|---|
| C1 | 사실 추가 | `delete_all_actors()` 공식 API 확인 → Orchestrator 표준 cleanup 스텝으로 확정 | 5.10, 8.2, 16.4 |
| C2 | 사실 추가 | `is_ignore_init_ego` 파라미터 확인 → 시나리오 간 Ego 상태 이월 존재. V3/V5 실험 매트릭스 확장 | 5.11, 12(V3/V5) |
| C3 | 사실 추가 | `get_states_vehicle/pedestrian/object` gRPC polling 확인 → 데이터 소스 3원화 (CSV/rosbag/API polling) | 5.12, 9.4 |
| C4 | 사실 추가 | `set_weather()` / `set_time_of_day()` 확인 → v2 환경 변인 sweep 백로그 등록 | 5.13, FR-13 |
| C5 | 리스크 추가 | 공식 예제가 QApplication 이벤트 루프 의존 → Runner 클라이언트 측 Headless 리스크 (R11) | 6.6, 14 |
| C6 | 전제 수정 | SIM Synchronous Mode는 문서상 "ROS에서만 지원" 명시 → ROS2 파이프라인에서 재현성 최후 수단 성립 여부 검증 필요 (R12) | 6.7, 12(V3) |
| C7 | 설계 공백 보완 | per-scenario 완료 이벤트 부재 → 시나리오 경계 감지 상태머신 설계 추가, V1.5 신설 | 12(V1.5), 21.2 |
| C8 | 원칙 추가 | Decision 5: Metric 정본은 Scenario Runner 제공 지표, 자체 계산은 크로스체크용 | 15 |
| C9 | 절차 수정 | 재현성 허용 기준(±5%/±10%)을 임의값에서 실측 캘리브레이션 절차로 변경 | 12(V3), 13.6 |
| C10 | 절차 추가 | V8 이전 "로그 스키마 인벤토리" 단계 신설 | 12(V7.5) |
| C11 | 품질 추가 | Evidence Store에 SHA256 manifest 도입, VERSIONS.lock에 API smoke test 결과 포함 | 9.5, 11(Phase 0) |
| C12 | 신규 장 | 21장 "구현 엔지니어링 설계", 22장 "Framework 자체 검증 전략" 신설 | 21, 22 |

---

## 0. Executive Summary

본 프로젝트의 본질은 **MORAI SIM을 자동으로 실행하는 것**이 아니라, MORAI SIM과 Scenario Runner를 실행 엔진으로 활용하여 **재현 가능하고 추적 가능한 자동 시나리오 평가 Framework**를 구축하는 것이다.

Scenario Runner는 OpenSCENARIO(`.xosc`) 기반 시나리오를 로드하고, MORAI SIM과 gRPC로 통신하여 차량과 객체를 제어한다. 시나리오 해석에는 MGeo 기반의 논리적 지도 정보가 사용되며, 실제 차량 동역학·센서·충돌·렌더링은 MORAI SIM이 담당한다. 따라서 Scenario Runner 단독 실행은 불가능하며 MORAI SIM은 필수 구성요소이다.

**v1.1에서 확정된 추가 사실:**

1. `delete_all_actors()`, `is_ignore_init_ego`, `get_states_*()`, `set_weather()`, `set_time_of_day()`가 공식 API로 존재한다. Actor 잔존 리스크(R8)의 대응책은 이미 공식 기능으로 존재하므로 검토 대상이 아니라 표준 절차로 확정한다.
2. 공식 예제 코드는 QApplication 이벤트 루프에 의존한다. Headless 리스크는 SIM뿐 아니라 Runner 클라이언트 측에도 존재할 수 있으므로 Phase 0에서 검증한다.
3. SIM의 Synchronous Mode는 공식 문서상 ROS에서만 지원된다고 명시되어 있다. ROS2 Native 파이프라인에서 재현성 확보 수단으로 사용 가능한지는 미확정이다.
4. Python API에는 per-scenario 완료 이벤트가 없다(batch 단위 start/stop callback만 존재). **시나리오 경계 감지는 Orchestrator가 polling 기반 상태머신으로 직접 구현해야 하며, 이것이 Phase 1의 최대 기술 난제이다.**

PM 관점의 1차 목표는 변함없이 다음 세 가지다.

1. **Built-in 기준선 평가** — Autoware 없이 Scenario 자체의 실행성·논리·평가 가능성 검증
2. **자동 로깅 및 평가 파이프라인** — eventlog/statelog + rosbag2 + API polling의 3원 데이터 소스, metrics.csv, verdict.json, report.html
3. **Batch 및 Multi-Map 자동화 가능성 검증** — `set_map()` 부재가 확인되었으므로 V4/V5 실험으로 운영 전략 확정

목표 아키텍처는 다음과 같다.

```text
Scenario Catalog
      │
      ▼
Test Suite Manager
      │
      ▼
Simulation Orchestrator ──── Watchdog / State Machine
      │
      ▼
Scenario Runner Adapter (Python API + Qt 의존성 격리)
      │ gRPC
      ▼
MORAI SIM
      │
 ┌────┼─────────────────┐
 ▼    ▼                 ▼
Scenario Logs   ROS2 Bags   API State Polling
 └────┴────────┬────────┘
               ▼
         Metric Engine (정본: Runner 지표 / 보조: 자체 계산)
               │
               ▼
         Report Generator
               │
               ▼
         Evidence Store (SHA256 manifest)
```

---

## 1. 문서 목적

본 문서는 MORAI SIM 기반 자동화 평가 Framework 구축을 위해 다음을 정의한다.

- 공식 문서에서 확인된 사실과 미확인 사항의 구분
- MORAI SIM, Scenario Runner, MGeo, ROS2, Autoware의 역할 구분
- 자동화 가능 범위와 한계
- Built-in 기준선 평가를 먼저 수행해야 하는 이유
- 사전 검증 항목과 성공/실패 기준
- 자동화 평가 Framework의 목표 아키텍처
- **[v1.1] 구현 엔지니어링 설계: 상태머신, 실패 처리, 데이터 무결성**
- **[v1.1] Framework 자체(테스트 도구)의 검증 전략**
- PM 관점의 단계별 개발 로드맵과 리스크

이 문서는 단순 사용법이 아니라, 향후 구현·검증·확장 판단에 사용할 **설계 기준 문서**이다.

---

## 2. 문제 정의

### 2.1 현재 문제

| 문제 | 영향 |
|---|---|
| GUI 조작 의존 | 반복 실행 비용 증가 |
| 결과 저장 방식 불명확 | 재현성 및 추적성 저하 |
| 시나리오별 결과 비교 어려움 | 회귀시험 불가능 |
| Scenario 오류와 ADS 오류 구분 어려움 | 디버깅 비용 증가 |
| Map / MGeo / ROS / Autoware 문제가 섞임 | 원인 분리 어려움 |
| 수십~수백 개 시나리오 실행 어려움 | 대규모 검증 불가 |

프로젝트 목표는 "GUI를 덜 쓰는 것"이 아니라, **시나리오 실행·로깅·평가·리포트를 일관된 방식으로 자동화하는 것**이다.

---

## 3. 프로젝트 목표

### 3.1 최종 목표

**MORAI SIM 기반 Scenario Validation Automation Framework 구축**

```text
시나리오 목록 관리 → 자동 실행 → 자동 로깅 → 자동 Metric 계산
→ PASS/FAIL 판정 → 결과 리포트 생성 → 회귀시험
→ 향후 Autoware/External 평가 확장
```

### 3.2 1차 목표

**Built-in 기반 Baseline Evaluation Framework.** Autoware를 붙이기 전에 다음을 검증한다.

- `.xosc`가 정상 로드되는가?
- MGeo와 시뮬레이터 Map이 일치하는가?
- Ego/NPC/Pedestrian/Obstacle이 정상 Spawn 되는가?
- Trigger와 Action이 의도대로 발생하는가?
- StopTrigger 또는 Evaluation 조건에 의해 정상 종료되는가?
- Scenario Runner 로그가 정상 생성되는가?
- ROS2 topic 또는 rosbag을 통해 평가에 필요한 상태 데이터가 수집되는가?
- **[v1.1] Orchestrator가 시나리오 경계를 안정적으로 감지할 수 있는가?**
- 동일 시나리오 반복 실행 시 결과가 재현 가능한가?

### 3.3 확장 경로

```text
Built-in Baseline → External Controller → Autoware Closed-loop
→ Regression Test → CI/CD Simulation → Scenario Validation Platform
```

---

## 4. Scope 정의

### 4.1 In Scope

- MORAI SIM + Scenario Runner 구조 분석
- Scenario Runner Python API 기반 자동 실행 (Qt 의존성 검증 포함)
- Built-in 제어 모드 기반 기준선 평가
- Scenario Runner eventlog/statelog 수집
- ROS2 topic / rosbag2 기반 데이터 저장
- **[v1.1] API polling 기반 상태 수집 (3차 데이터 소스)**
- 자동 Metric 계산 구조 (Runner 지표 정본 원칙)
- Report 생성 구조
- 지도 자동 로드 및 Multi-Map Batch 검증 계획
- **[v1.1] Framework 자체의 단위/통합 테스트 전략**
- 향후 External / Autoware 연동을 위한 확장 구조

### 4.2 Out of Scope (v1.1)

- Autoware 전체 closed-loop 성능 평가
- Autoware perception/planning/control 상세 튜닝
- Headless MORAI SIM 운영 확정
- 클라우드/클러스터 기반 대규모 병렬 실행
- Scenario 자동 생성
- ISO 34501~34505 정식 적합성 인증 절차
- **[v1.1] 환경 변인(weather/time-of-day) sweep — v2 백로그(FR-13)로 등록**

단, 위 항목들은 향후 확장 가능성을 고려하여 아키텍처에 반영한다.

---

## 5. 공식 문서 기반 핵심 사실

> 이 장은 추론이 아니라 공식 문서에서 확인된 사실에 기반한다. v1.1에서 5.10~5.14를 추가했다.

### 5.1 Scenario Runner의 역할

Scenario Runner는 ASAM OpenSCENARIO 형식의 `.xosc` 시나리오를 로드하고, MORAI SIM과 gRPC 기반으로 통신하여 차량 및 물체를 제어한다.

- Scenario Runner는 물리 시뮬레이터가 아니다.
- 시나리오 실행과 조건 판단을 담당한다.
- MORAI SIM이 실제 시뮬레이션 엔진이다.

### 5.2 MGeo의 역할

시나리오는 MGeo 형식의 논리 지도를 기반으로 정의된다. Trigger, Route, Position, Lane 기반 판단에 필요하며, MORAI SIM Map과 MGeo가 불일치하면 Trigger/Route/Spawn 오류가 발생할 수 있다.

### 5.3 Ego 제어 모드

| 모드 | 의미 | 프로젝트 활용 |
|---|---|---|
| Built-in | Scenario Runner가 Ego를 시나리오 정의에 따라 제어 | 시나리오 품질 검증 / 기준선 |
| MORAI SIM: Drive | 초기 상태만 정의, MORAI SIM 로직 사용 | 제한적 활용 |
| External | 초기 상태만 정의, 외부 알고리즘이 Ego 제어 | Autoware 평가 |

### 5.4 Batch Simulation

Python API에서 `set_scenario_config()`로 시나리오 파일 목록, 제어 모드, Sync Mode, 반복 횟수를 지정하고 `start_batch_scenario()`를 호출하여 Batch Simulation을 수행할 수 있다.

### 5.5 지도 자동 로드

공식 문서에는 "시나리오 시작 시 MORAI SIM: Drive가 자동으로 대상 지도를 로드한다"고 설명되어 있으나, Python API에 명시적 `set_map()` 함수는 존재하지 않는다(`get_available_map()` 조회만 가능). Multi-Map Batch 가능 여부는 V4/V5 실험으로 검증한다.

### 5.6 Scenario Runner 결과 로그

```text
logs_scenario_runner/
  simulation_{배치 시뮬레이션 수행 시각}/
    {수행시각}_{지도이름}_{시나리오이름}_eventlog.csv
    {수행시각}_{지도이름}_{시나리오이름}_statelog.csv
```

파일명에 지도 이름과 시나리오 이름이 포함되므로 결과 추적성이 확보된다. 단, **컬럼 스키마는 공식 문서에 완전히 명세되어 있지 않으므로 V7.5(로그 스키마 인벤토리)에서 실측으로 확정한다.**

### 5.7 Scenario Runner 평가 지표

Safe Distance, Time To Collision, Way-off Distance, Lateral/Longitudinal Acceleration, Speed Excess, Speed Deficit를 제공한다. **[v1.1] 이 지표들이 Metric의 정본(source of truth)이다(Decision 5).**

### 5.8 ROS2 Native

MORAI SIM: Drive 26.R1.0에 ROS2 Native 통신 인터페이스, ROS2 메시지, ROS2 설정 UI가 추가되었다.

> **[ERRATUM 2026-07-06]** 실측 반증 — 26.R1.H3의 ROS2 Native(ros2cs, standalone=0)는 host ROS2 Humble과
> ABI 불일치로 SIM이 startup에서 `std::bad_cast` 종료(DDS participant 미생성, D1=FAIL, 3회 재현). rosbridge
> 경로는 SIM이 ROS1 헤더(`header.seq`)로 발행해 rosbridge_suite가 전 메시지 거부(데이터 0). 26.R1.H3에서
> ROS2 Native/rosbridge 무인 연동은 현재 불가. **AVS-007**(D1=FAIL 확정), MORAI 회신 대기(MORAI-001).
> 무인 데이터 경로에서 ROS2 Native 제외(**ADR-009**).

### 5.9 Rosbag Replay

MORAI SIM은 Rosbag을 이용해 Ego 주행 데이터 및 주변 환경 데이터를 저장·재현하는 기능을 제공한다. Rosbag은 재현성 확보를 위한 핵심 artifact이다.

### 5.10 [v1.1 신규] delete_all_actors()

Spawn된 모든 객체를 삭제하는 함수가 공식 API에 존재하며, 실패 시 에러가 출력된다.

**설계 의미**

- Risk R8(Actor 잔존)의 대응책이 이미 공식 기능으로 존재한다.
- Orchestrator의 시나리오 간 **표준 cleanup 스텝**으로 확정한다.
- V5 검증 항목을 "delete_all_actors 호출 후 잔존 여부 확인"으로 구체화한다.

### 5.11 [v1.1 신규] is_ignore_init_ego

시나리오 설정에 이전 시나리오의 Ego 위치·속도 값을 무시할지 결정하는 파라미터가 존재한다.

**설계 의미**

- Batch 내 시나리오 간 **Ego 상태 이월이 실제로 존재한다**는 방증이다.
- V3(반복 재현성)과 V5(Multi-Map)는 이 플래그 True/False 양쪽으로 실험 매트릭스를 구성해야 한다.
- 기준선 평가의 기본값은 `is_ignore_init_ego=True`(상태 이월 차단)로 하고, 실측으로 확인한다.

### 5.12 [v1.1 신규] get_states_vehicle / pedestrian / object

gRPC polling으로 actor 상태를 직접 조회할 수 있다.

**설계 의미**

- 데이터 소스가 eventlog/statelog, rosbag 두 개가 아니라 **세 개**다.
- rosbag QoS 문제(R5)나 statelog 필드 부족(R4) 발생 시 fallback으로 활용한다.
- 단, polling 주기는 gRPC 왕복 지연에 의해 제한되므로 고주파 데이터(동역학 상세)는 rosbag이 우선이다.

### 5.13 [v1.1 신규] set_weather() / set_time_of_day()

날씨(Sunny~Snowy 등)와 시간대를 API로 제어할 수 있다.

**설계 의미**

- 동일 `.xosc`에 환경 축을 곱한 variation sweep이 가능하다.
- v1에서는 구현하지 않고 FR-13으로 백로그 등록, Scenario Catalog 스키마에 환경 축 필드만 예약한다.

### 5.14 [v1.1 신규] API 문서 신뢰도 한계

- 공식 예제 코드는 QApplication 이벤트 루프 내에서 API를 실행한다(→ 6.6).
- `get_storyboard_element`는 문서 시그니처(무인자)와 예제 코드(`"Event1"` 인자)가 불일치한다.
- Python API 문서의 최종 수정 시점이 26.R1 릴리즈보다 오래되어, Runner 버전별 API 스펙 차이가 있을 수 있다.

**설계 의미**

- 문서만 믿지 않는다. **Phase 0에서 API 계약(contract)을 실측으로 확정하고 `api_contract.md`로 기록한다.**
- VERSIONS.lock에 "Runner 버전 + API smoke test 결과"를 함께 기록한다.

---

## 6. 핵심 기술 고찰

### 6.1 Scenario Runner 단독 실행은 가능한가?

**불가능하다.** Scenario Runner는 MGeo를 가지고 있으나 물리 엔진, 센서 모델, 차량 동역학, 충돌 계산을 수행하지 않는다. MGeo만으로 가능한 것은 정적 분석(Road Network parsing, Lane/Link/Node 확인, Route 참조, 위치 정의 검토)뿐이다.

### 6.2 왜 Built-in부터 평가해야 하는가?

Autoware를 곧바로 연동하면 Scenario/Map/MGeo/Spawn/Trigger/SIM 설정/ROS2 통신/localization/planning/control adapter 오류가 모두 섞여 원인 분리가 불가능해진다. Built-in 검증의 목적:

| 목적 | 설명 |
|---|---|
| Scenario 실행성 검증 | `.xosc`가 정상 로드되고 실행되는가 |
| 논리 검증 | Trigger/Action이 의도대로 발생하는가 |
| Map 정합성 검증 | MGeo와 SIM Map이 맞는가 |
| 평가 가능성 검증 | 로그로 Metric을 계산할 수 있는가 |
| 기준선 생성 | 이후 Autoware 결과와 비교할 Baseline 확보 |

### 6.3 MGeo와 MORAI SIM Map의 관계

MGeo는 논리 지도(Lane/Node/Link/Junction/Trigger·Route 계산), MORAI SIM Map은 실제 시뮬레이션 월드(Rendering/Physics/Collision/Sensor)이다. 불일치 시 Spawn 위치 오류, Trigger 위치 오류, Route 계산 실패, 지도 자동 로드 실패가 발생할 수 있다.

### 6.4 Map 자동 변경은 어떻게 볼 것인가?

공식 문서에는 자동 로드 설명이 있으나 Python API에 명시적 map control 함수는 없다.

```text
가정:
- .xosc 또는 시나리오 설정이 대상 Map/MGeo를 참조한다.
- Scenario Runner가 실행 시 해당 지도 로드를 MORAI SIM에 요청한다.

검증 필요 (V4/V5):
- A Map 로드 상태에서 B Map 시나리오를 Python API로 실행 시 자동 전환 여부
- Map 전환 후 이전 Actor/상태의 완전 초기화 여부 (delete_all_actors 호출 전후 비교)
```

### 6.5 Headless 실행은 어떻게 볼 것인가?

MORAI SIM Drive 26.R1에서 `-batchmode`, `-nographics` 등 Headless 실행이 공식 지원된다는 근거는 부족하다.

| 구분 | 판단 |
|---|---|
| Scenario Runner Python API Batch | 1차 자동화 대상으로 추진 |
| GUI 최소화 | 가능성 높음 |
| Headless MORAI SIM | 별도 R&D 검증 항목 |
| CI/CD 서버 실행 | Headless 가능성 확인 후 추진 |

### 6.6 [v1.1 신규] Python API의 Qt 의존성 문제

공식 예제 코드는 QApplication을 생성하고 이벤트 루프(`App.exec()`)를 유지한 상태에서 API를 별도 스레드로 실행하는 구조다.

**문제**

- API가 Qt 이벤트 루프에 실제로 의존한다면, "순수 Python 스크립트 + cron/CI" 형태의 자동화 그림이 달라진다.
- Headless 리스크가 MORAI SIM뿐 아니라 **Runner 클라이언트 측에도 존재**한다.

**검증 방법 (Phase 0)**

```text
실험 1: QApplication 없이 API client 생성 → is_connected() → start_batch_scenario()
  → 정상 동작: Qt 의존성 없음, 순수 스크립트로 진행
  → gRPC callback 미수신/hang: 실험 2로

실험 2: QCoreApplication(GUI 없는 Qt 이벤트 루프)로 대체
  → 정상 동작: 서버 환경에서도 실행 가능 (DISPLAY 불필요)
  → 실패: xvfb 등 가상 디스플레이 전략 수립 (R11)
```

**설계 대응**

- Scenario Runner Adapter를 별도 프로세스로 격리하고, Orchestrator와는 파일/IPC로 통신하는 구조를 기본으로 한다(21.1). Qt 의존성이 확인되더라도 Adapter 프로세스 내부에만 국한된다.

### 6.7 [v1.1 신규] Synchronous Mode의 ROS 의존성 문제

SIM Drive 26.R1 공식 문서의 Synchronous Mode 페이지에는 해당 기능이 **"현재 ROS에서만 지원"** 된다고 명시되어 있다.

**문제**

- 본 Framework는 ROS2 Native 파이프라인을 전제로 한다.
- V3에서 반복 실행 편차가 클 경우의 대응책이 "sync mode 적용 검토"인데, 그 전제가 성립하지 않을 수 있다.
- 또한 Scenario Runner Python API의 `sync_mode` 파라미터와 SIM의 Synchronous Mode가 **같은 메커니즘인지 별개인지**도 공식 문서만으로는 확정할 수 없다.

**검증 방법 (V3 확장)**

```text
1. Runner sync_mode=True + ROS2 환경에서 batch 실행 → 동작/에러/무시 여부 확인
2. SIM 설정 UI의 Synchronous Mode 항목이 ROS2 선택 시 활성화되는지 확인
3. 둘 다 불가 시: 재현성 확보 수단을 sync mode가 아닌
   "고정 timestep 여부 확인 + 통계적 기준선(N회 분포)"으로 전환 (13.6)
```

이 항목은 재현성 전략의 근간이므로 **R12(신규 리스크)** 로 등재한다.

---

## 7. Framework 요구사항

### 7.1 Functional Requirements

| ID | 요구사항 | 설명 | 우선순위 |
|---|---|---|---|
| FR-01 | Scenario Catalog 관리 | `.xosc`, map, tag, ODD, expected behavior 관리 | High |
| FR-02 | Batch 실행 | 여러 시나리오 순차 실행 | High |
| FR-03 | Built-in 실행 | Autoware 없이 Baseline 평가 | High |
| FR-04 | External 실행 | 향후 Autoware 평가 지원 | Medium |
| FR-05 | 로그 수집 | eventlog/statelog/rosbag 자동 저장 | High |
| FR-06 | Metric 계산 | Runner 지표 수집 + 자체 크로스체크 계산 | High |
| FR-07 | PASS/FAIL 판정 | Scenario별 판정 기준 적용 | High |
| FR-08 | Report 생성 | HTML/CSV/PDF 결과 생성 | Medium |
| FR-09 | Multi-Map 실행 | 서로 다른 Map 시나리오 batch | Medium |
| FR-10 | 반복 실행 | 재현성 검증 | High |
| FR-11 | 결과 비교 | Built-in vs External/Autoware 비교 | Medium |
| FR-12 | Failure 분석 | 실패 원인 분류 (오류 분류 체계 21.4) | Medium |
| FR-13 | [v1.1] 환경 변인 sweep | set_weather/set_time_of_day 기반 variation | Low (v2) |
| FR-14 | [v1.1] 시나리오 경계 감지 | per-scenario 시작/종료를 Orchestrator가 감지 | **High** |
| FR-15 | [v1.1] 상태 이월 차단 | is_ignore_init_ego + delete_all_actors 표준화 | High |

### 7.2 Non-Functional Requirements

| ID | 요구사항 | 설명 |
|---|---|---|
| NFR-01 | Reproducibility | 동일 조건에서 동일 결과 재현 (기준은 실측 캘리브레이션) |
| NFR-02 | Traceability | 시나리오, map, SW version, 로그, 결과 연결 |
| NFR-03 | Scalability | 수십~수백 개 시나리오 실행 가능 |
| NFR-04 | Observability | 실패 원인 추적 가능한 로그 구조 + 오류 분류 체계 |
| NFR-05 | Extensibility | Metric, Simulator, Controller 확장 가능 |
| NFR-06 | Robustness | 실패한 시나리오가 전체 batch를 망치지 않도록 설계 |
| NFR-07 | Version Control | 시나리오, 설정, 평가 기준, API contract 버전 관리 |
| NFR-08 | Evidence Quality | SHA256 manifest 포함, Safety Case 증적 활용 가능 |
| NFR-09 | [v1.1] Atomicity | 결과 쓰기는 원자적(tmp→rename), 부분 결과 오염 방지 |
| NFR-10 | [v1.1] Testability | Framework 자체가 SIM 없이 단위 테스트 가능한 구조 |

---

## 8. Target Architecture

### 8.1 Logical Architecture

```text
┌──────────────────────────────────────┐
│ Scenario Catalog                     │
│ - xosc / map / ODD tag               │
│ - expected behavior                  │
│ - (예약) weather / time-of-day 축     │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ Test Suite Manager                   │
│ - scenario selection / iteration     │
│ - controller mode / pass-fail 기준    │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ Simulation Orchestrator              │
│ - run lifecycle state machine        │
│ - scenario boundary detection        │
│ - watchdog / timeout / retry         │
│ - cleanup (delete_all_actors)        │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ Scenario Runner Adapter (별도 프로세스)│
│ - Python API wrapper (Qt 격리)        │
│ - start/stop/skip                    │
│ - storyboard / actor state polling   │
└──────────────────┬───────────────────┘
                   │ gRPC
                   ▼
┌──────────────────────────────────────┐
│ MORAI SIM                            │
│ - physics / sensor / collision       │
│ - ROS2 native                        │
└──────────────────┬───────────────────┘
          ┌────────┼─────────────┐
          ▼        ▼             ▼
┌──────────────┐ ┌───────────┐ ┌────────────────┐
│Scenario Logs │ │ROS2 Bags  │ │API State Poller │
│event/statelog│ │rosbag2    │ │(fallback 소스)   │
└──────┬───────┘ └─────┬─────┘ └───────┬─────────┘
       └───────────────┼───────────────┘
                       ▼
┌──────────────────────────────────────┐
│ Metric Engine                        │
│ - 정본: Runner 제공 지표 파싱          │
│ - 보조: statelog/rosbag 자체 계산      │
│ - 크로스체크 및 불일치 보고            │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ Report Generator                     │
│ - metrics.csv / report.html          │
│ - summary.json                       │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ Evidence Store                       │
│ - raw data / logs / metadata         │
│ - SHA256 manifest.json               │
└──────────────────────────────────────┘
```

### 8.2 Component Responsibilities

| Component | 책임 |
|---|---|
| Scenario Catalog | 시나리오 자산과 메타데이터 관리 |
| Test Suite Manager | 실행할 시나리오 목록과 조건 정의 |
| Simulation Orchestrator | 실행 순서, 경계 감지, timeout, cleanup, 오류 처리, retry |
| Scenario Runner Adapter | Python API 추상화, Qt 의존성 격리, 상태 polling |
| MORAI SIM Adapter | ROS2 topic, sim 상태, map 상태 확인 |
| Logger | eventlog/statelog/rosbag/API poll/metadata 수집 |
| Metric Engine | Runner 지표 정본 수집 + 자체 계산 크로스체크 |
| Report Generator | 사람이 읽을 수 있는 결과 생성 |
| Evidence Store | 실험 증적 보관 + 무결성 manifest |

---

## 9. 데이터 및 Artifact 설계

### 9.1 결과 디렉터리 구조

```text
results/
  {test_suite_id}/
    suite_metadata.json
    suite_summary.csv
    suite_report.html
    manifest.sha256              # [v1.1] suite 레벨 무결성

    {map_id}/
      {controller_mode}/          # builtin / external
        {scenario_id}/
          run_001/
            scenario.xosc         # 실행 시점 사본
            metadata.json
            eventlog.csv
            statelog.csv
            rosbag/
            api_poll.jsonl        # [v1.1] API polling 기록 (활성화 시)
            metrics.csv
            verdict.json
            report.html
            manifest.sha256       # [v1.1] run 레벨 무결성
            logs/
              orchestrator.log
              scenario_runner_api.log
              state_machine.log   # [v1.1] 경계 감지 전이 기록
```

### 9.2 metadata.json 예시

```json
{
  "test_suite_id": "baseline_kcity_2026_07_03",
  "run_id": "run_001",
  "scenario_id": "Scenario_CCRB_001",
  "scenario_file": "Scenario_CCRB_001.xosc",
  "scenario_sha256": "a1b2c3...",
  "map_id": "R_KR_PG_K-City",
  "controller_mode": "BuiltIn",
  "sync_mode": false,
  "is_ignore_init_ego": true,
  "iteration": 1,
  "morai_sim_version": "26.R1.x",
  "scenario_runner_version": "1.7.x",
  "api_contract_version": "contract_2026_07",
  "ros_distro": "humble",
  "rmw": "rmw_cyclonedds_cpp",
  "wall_start_time": "2026-07-03T10:00:00+09:00",
  "wall_end_time": "2026-07-03T10:02:31+09:00",
  "sim_clock_offset_sec": 0.042,
  "boundary_detection": {
    "start_signal": "scenario_name_change",
    "end_signal": "storyboard_complete",
    "detection_latency_sec": 0.31
  },
  "result": "PASS",
  "error_code": null
}
```

### 9.3 metrics.csv 예시

| metric | value | unit | threshold | source | verdict |
|---|---:|---|---:|---|---|
| collision | 0 | bool | 0 | runner | PASS |
| min_ttc | 2.31 | sec | >= 1.50 | runner | PASS |
| min_ttc_selfcalc | 2.28 | sec | (crosscheck) | statelog | INFO |
| min_distance | 4.80 | m | >= 2.00 | runner | PASS |
| max_lateral_acc | 2.10 | m/s² | <= 3.50 | runner | PASS |
| max_longitudinal_acc | 4.80 | m/s² | <= 6.00 | runner | PASS |
| max_wayoff_distance | 0.22 | m | <= 0.50 | runner | PASS |
| scenario_duration | 31.2 | sec | <= 60.0 | orchestrator | PASS |
| timeout | 0 | bool | 0 | orchestrator | PASS |
| crosscheck_max_dev | 1.3 | % | <= 5.0 | engine | PASS |

**[v1.1] `source` 컬럼 신설**: 각 값이 Runner 지표인지, 자체 계산인지, Orchestrator 측정인지 명시한다. 크로스체크 불일치가 허용치를 넘으면 지표 자체를 신뢰할 수 없으므로 verdict는 `INCONCLUSIVE`로 분류한다.

### 9.4 [v1.1 신규] 3원 데이터 소스 전략

| 소스 | 강점 | 약점 | 역할 |
|---|---|---|---|
| eventlog/statelog | 공식 산출물, 시나리오 이벤트 정합 | 스키마 미공개, 필드 제한 가능 | **정본** (Runner 지표) |
| rosbag2 | 고주파, 재생 가능, 표준 도구 | QoS/topic 변경 리스크 | 상세 분석·재현 |
| API polling | 의존성 최소, 즉시 확인 | 주기 제한(gRPC 지연) | fallback·경계 감지 |

> **[ERRATUM 2026-07-06, ADR-009]** 무인/유인 구분 추가 — **무인 경로(주)**: eventlog/statelog(정본) + API polling.
> **유인 세션 한정**: rosbag2(ROS2 Native 전제인데 AVS-007로 무인 불가). 무인 L6 성숙도 전제에서 ROS2 Native 제외.
> ([v1.1] statelog 스키마는 `runbooks/log_schema_inventory.md`에서 실측 확정 — 지표 6종 전부 statelog 존재.)

### 9.5 [v1.1 신규] 무결성 manifest

run 종료 시 결과 폴더 내 모든 파일의 SHA256을 `manifest.sha256`으로 생성한다. Safety case 증적으로 제출할 때 변조·유실 여부를 기계적으로 검증할 수 있다.

---

## 10. 자동화 성숙도 모델

| Level | 이름 | 설명 | 목표 상태 |
|---|---|---|---|
| L0 | Manual GUI | 모두 GUI 수동 | 현재 초기 상태 |
| L1 | Assisted Logging | GUI 실행 + 로그/rosbag 자동 수집 | 즉시 가능 |
| L2 | API Batch | Python API로 `.xosc` batch 실행 + 경계 감지 | 1차 MVP |
| L3 | Auto Evaluation | Metric 수집·계산 및 PASS/FAIL 자동화 | 핵심 목표 |
| L4 | Regression Test | 다수 시나리오 반복 회귀시험 | 연구개발 운영 |
| L5 | External Controller | Autoware 등 외부 알고리즘 평가 | 2차 목표 |
| L6 | Headless/CI | GUI 없는 서버/야간 자동 실행 | 장기 목표 |

v1.1의 현실적 목표는 **L2~L3**이다. L2의 정의에 "시나리오 경계 감지"를 포함시킨 것이 v1.0과의 차이다 — 경계 감지 없는 batch 실행은 artifact 분리가 불가능하므로 L2로 인정하지 않는다.

---

## 11. 단계별 개발 로드맵

### Phase 0. 환경 안정화 + API 계약 검증 [v1.1 확장]

**목표**

MORAI SIM, Scenario Runner, ROS2가 독립적으로 정상 동작하는지 확인하고, **Python API의 실제 동작 계약을 실측으로 확정**한다.

**Deliverables**

- `VERSIONS.lock` (SIM/Runner/ROS2/RMW 버전 + **API smoke test 결과 포함**)
- `api_contract.md`: 함수별 실측 시그니처, 반환 타입, 예외 동작, callback 발생 시점
- Qt 의존성 검증 결과 (6.6의 실험 1/2)
- Scenario Runner 실행 확인 로그, ROS2 topic 확인 결과

**Acceptance Criteria**

- MORAI SIM 실행 가능, Scenario Runner 창 실행 가능
- 예제 `.xosc` 수동 Built-in 실행 가능
- `/clock` 또는 MORAI ROS2 topic 확인 가능
- **QApplication 필요 여부 확정** (필요 시 Adapter 프로세스 격리 설계 확정)
- **`get_storyboard_element` 등 문서-예제 불일치 함수의 실제 시그니처 확정**

---

### Phase 1. Built-in Batch Runner MVP + 경계 감지 [v1.1 확장]

**목표**

Python API를 통해 Built-in 모드로 단일/복수 시나리오를 실행하고, **시나리오 경계를 안정적으로 감지**한다.

**Deliverables**

- `scenario_batch_runner.py`, `test_suite.yaml`, `run_builtin_suite.sh`
- `boundary_detector.py` (21.2 상태머신 구현)
- `state_machine.log` (전이 기록)

**Acceptance Criteria**

- `is_connected()` 성공
- 단일 `.xosc` 실행 성공, 복수 `.xosc` 순차 실행 성공
- `eventlog.csv`, `statelog.csv` 생성
- **시나리오 N의 종료와 N+1의 시작을 Orchestrator가 오탐 없이 감지 (3개 시나리오 batch에서 경계 6회 전부 정확)**
- 실패 시 timeout 또는 error 상태 기록

---

### Phase 2. Logging & Artifact Manager

**목표**

Scenario Runner 로그와 ROS2 rosbag을 표준 폴더 구조로 저장한다.

**Deliverables**

- `artifact_manager.py`, `rosbag_recorder.py`(subprocess wrapper), `metadata.json`, `manifest.sha256`

**Acceptance Criteria**

- 시나리오 실행마다 독립 결과 폴더 생성 (원자적 쓰기: tmp → rename)
- scenario.xosc 사본 + SHA256 저장
- eventlog/statelog 수집 (Runner 로그 폴더 → run 폴더 매핑 검증)
- rosbag 저장 (경계 감지와 연동한 시작/종료)
- **실패 케이스도 로그 보존 + error_code 기록**

---

### Phase 3. Metric Engine v1

**목표**

**Runner 제공 지표를 정본으로 수집**하고, statelog 기반 자체 계산으로 크로스체크한다.

**Deliverables**

- `metric_engine.py`, `metrics.csv`(source 컬럼 포함), `verdict.json`, `thresholds.yaml`

**1차 Metric**: Collision, Scenario duration, Timeout, Min TTC, Min safe distance, Max way-off distance, Max lateral/longitudinal acceleration, Speed excess/deficit

**Acceptance Criteria**

- Runner 지표 파싱 성공률 100% (파싱 불가 시 INCONCLUSIVE)
- 자체 계산과 Runner 지표의 편차 보고
- threshold 기반 PASS/FAIL/INCONCLUSIVE 3분류 판정
- 사람이 검토 가능한 csv/json 출력

---

### Phase 3.5. 로그 스키마 인벤토리 [v1.1 신설, 구 V8 선행]

**목표**

eventlog/statelog/rosbag의 실제 스키마를 실측으로 확정하고 버전 관리한다.

**Deliverables**

- `schema_inventory.py`: 컬럼/토픽/타입 자동 덤프
- `schemas/statelog_schema.json`, `schemas/eventlog_schema.json`, `schemas/topics.json`

**Acceptance Criteria**

- 전체 컬럼 목록·타입·단위·좌표계 문서화
- Metric 계산에 필요한 필드의 존재 여부 판정 → 부족 시 rosbag/API polling 보강 계획 수립
- Runner 버전 변경 시 스키마 diff 자동 감지

---

### Phase 4. Multi-Map Batch 검증

**목표**

서로 다른 지도의 시나리오를 Python API Batch로 연속 실행 가능한지 확인한다.

**Deliverables**

- `multi_map_test_suite.yaml`, Multi-Map 실행 결과, map transition validation report

**Acceptance Criteria**

- A Map 로드 상태에서 B Map 시나리오 실행 시 자동 전환 여부 확인
- 로그 파일명에 올바른 지도 이름 기록
- **delete_all_actors 호출 전/후 각각에 대해** Map 전환 후 actor 잔존 여부 확인
- **is_ignore_init_ego True/False 매트릭스 실행**
- 실패 시 Map 단위 batch 분리 전략 수립

---

### Phase 5. Report Generator

**목표**: 실행 결과를 HTML/CSV로 자동 요약한다.

**Deliverables**: `report_generator.py`, `suite_report.html`, `suite_summary.csv`

**Acceptance Criteria**

- Scenario별 PASS/FAIL/INCONCLUSIVE 표시, Metric 표, 실패 원인 분류(오류 코드), 로그/rosbag 경로 링크, 반복 실행 편차 요약

---

### Phase 6. External / Autoware 연동 준비

**목표**: Built-in 기준선과 동일 시나리오를 External 모드로 실행하여 외부 제어기 평가 구조를 준비한다.

**Deliverables**: External mode test script, ROS2 topic mapping checklist, Autoware adapter requirement list

**Acceptance Criteria**

- External 모드에서 Ego가 Scenario Runner에 의해 직접 제어되지 않음 확인
- 외부 제어 명령 topic이 MORAI Ego 제어와 연결되는지 확인
- Built-in 결과와 External 결과를 동일 Metric 체계로 비교 가능

---

### Phase 7. Headless/CI 가능성 검토

**목표**: GUI 없는 야간 실행 또는 CI 환경 가능성 검토. **[v1.1] SIM Headless와 Runner 클라이언트 Qt 의존성(R11)을 분리하여 검토한다.**

**Deliverables**: Headless feasibility report, GPU/CPU utilization report, remote execution checklist

**Acceptance Criteria**

- 공식 지원 여부 확인, 비공식 실행 옵션 실험 결과 확보
- 실패 시 "GUI 최소화 + API 자동화" 운영 전략 확정

---

## 12. 사전 검증 계획

### V0. 환경 검증

| 항목 | 기준 |
|---|---|
| MORAI SIM 실행 | 정상 Start 및 Map 로드 |
| Scenario Runner 실행 | 창 표시, 연결 가능 |
| ROS2 topic | `/clock` 또는 MORAI topic 확인 |
| GPU | `nvidia-smi`에서 MORAI 프로세스 확인 |
| 로그 | Scenario Runner 로그 위치 확인 |

### V1. Python API 연결 검증

**방법**: MORAI SIM + Scenario Runner 실행 → API Client 생성 → `is_connected()`, `get_simulator_version()`, `get_available_map()`

**PASS**: 연결 성공, 버전 반환, Map list 반환
**FAIL**: gRPC 연결 실패, 포트 오류, Runner/SIM 미실행
**[v1.1 추가]**: QApplication 유/무 양쪽에서 수행 (6.6 실험)

### V1.5. 시나리오 경계 감지 방법 확정 [v1.1 신설]

**목적**

per-scenario 완료 이벤트가 API에 없으므로, polling으로 경계를 감지할 수 있는 신호 조합을 확정한다. **이것이 확정되지 않으면 Phase 2의 artifact 분리가 불가능하다.**

**방법**

2개 시나리오 batch를 실행하며 아래 후보 신호를 100ms~500ms 주기로 동시 기록한다.

```text
후보 신호:
S1. get_current_scenario_name() 값 변화
S2. get_storyboard_state() (또는 상응 함수) 상태 전이
S3. get_simulation_time() 리셋(감소) 감지
S4. eventlog.csv 파일 생성/갱신 감지 (파일시스템 watch)
S5. batch start/stop callback (batch 전체 경계만)
```

**PASS**

- 최소 2개 신호의 조합으로 시나리오 시작/종료를 오탐·미탐 없이 감지
- 감지 지연 < 1초
- 감지 신호 조합을 `api_contract.md`에 기록

**FAIL 시 대응**

- Runner 로그 폴더의 파일 생성 이벤트(S4)를 주 신호로 하는 파일시스템 기반 감지로 전환
- 최악의 경우: batch를 시나리오 1개짜리 batch의 반복으로 분해 (start_batch_scenario를 시나리오당 1회 호출) — 성능 손해를 감수하고 경계를 API 호출 경계와 일치시킴

### V2. 단일 Built-in 시나리오 실행

**방법**: `.xosc` 1개, `ControllerFrom.BuiltIn`, `num_iterations=1`, `start_batch_scenario()`

**PASS**: Scenario 시작, Ego/NPC Spawn, Storyboard running → complete/end, eventlog/statelog 생성
**FAIL**: scenario load error, MGeo error, actor spawn error, timeout, crash
**의사결정**: FAIL이면 Scenario 품질 또는 Map/MGeo 정합성부터 수정

### V3. 동일 시나리오 반복 실행 (재현성) [v1.1 수정]

**방법**

- 동일 `.xosc`, Built-in, **1차: `num_iterations=20`** (기준 분포 확보), 이후 회귀시험은 3~5회
- **is_ignore_init_ego True/False 양쪽 매트릭스**
- sync_mode 파라미터의 실제 효과 확인 (6.7 — ROS2 환경에서 동작하는지)

**허용 기준 산정 절차 [v1.1 — 임의값 폐기]**

```text
1. N=20 반복 실행으로 각 Metric의 분포(평균, 표준편차, min/max) 확보
2. 허용 기준 = 평균 ± 3σ 또는 P1~P99 구간 (Metric별 선택)
3. 산정된 기준을 thresholds.yaml에 버전과 함께 기록
4. 이후 회귀시험에서 이 기준을 사용, 기준 변경은 PR 리뷰 대상
```

**PASS**: Trigger 순서 동일, Collision 결과 동일, PASS/FAIL 판정 동일, 연속 Metric이 캘리브레이션된 구간 내
**의사결정**: 분포가 비정상적으로 넓으면 sync mode 가능 여부(R12)와 timestep 설정을 먼저 확인. sync mode 불가 시 통계적 기준선으로 운영을 확정.

### V4. 현재 Map과 다른 Map의 시나리오 실행

**방법**: A Map 로드 → Python API로 B Map 기반 `.xosc` 실행 → 화면/로그/파일명/actor 확인

**PASS**: B Map 자동 로드, B Map 기준 actor 정상 spawn, 로그 파일명에 B Map 기록, Scenario complete
**PARTIAL**: 지도는 바뀌나 actor 위치 오류 / MGeo 로드되나 trigger 실패
**FAIL**: 지도 전환 없음, MGeo load 실패, scenario start 실패
**의사결정**: PASS → Multi-Map Batch 추진 / FAIL → Map 단위 batch 분리

### V5. Multi-Map Batch 실행 [v1.1 수정]

**방법**

```text
KCity/scenario_001.xosc → KCity/scenario_002.xosc
→ Pangyo/scenario_001.xosc → Pangyo/scenario_002.xosc

매트릭스:
- cleanup 정책: {없음, 시나리오 간 delete_all_actors 호출}
- is_ignore_init_ego: {True, False}
```

**PASS**: Map 전환 정상, 시나리오별 로그 생성, Batch 중단 없음, actor 잔존 없음
**FAIL**: Map 전환 후 crash, actor 잔존, 두 번째 Map 실행 실패
**의사결정**: PASS → 회귀시험 단위 = Test Suite / FAIL → 회귀시험 단위 = Map. cleanup 정책과 플래그의 효과를 정량 기록하여 표준 설정 확정.

### V6. MGeo Mismatch 검증

**방법**: 정상 `.xosc` 복사본의 RoadNetwork/LogicFile 참조를 의도적으로 오지정 후 실행 (운영용 시나리오 금지)

**PASS**: MGeo load error, route/trigger/spawn 오류 확인, 로그에 원인 기록
**의사결정**: MGeo validation tool 개발 필요성 판단. **[v1.1] 이때 관측된 오류 메시지·로그 패턴을 21.4 오류 분류 체계의 감지 규칙으로 등록한다.**

### V7. ROS2 Logging 검증

**방법**

```bash
ros2 topic list | grep -i -E "clock|ego|vehicle|object|npc|pedestrian|collision|tf"
ros2 bag record <필요 topic 목록> -o results/.../rosbag
```

**PASS**: `/clock`, Ego 상태, Object/NPC/Pedestrian 상태, (필요 시) collision/event topic 기록, rosbag 재생 가능
**FAIL**: topic 미출력, QoS 문제, bag 저장 실패, timestamp 불일치
**[v1.1 추가]**: sim time과 wall clock의 offset을 측정하여 metadata.json의 `sim_clock_offset_sec`에 기록. Runner CSV timestamp의 시간 기준(sim/wall)도 이 단계에서 확정한다.

### V7.5. 로그 스키마 인벤토리 [v1.1 신설]

Phase 3.5와 동일. V8(Metric 계산 검증)의 선행 조건이다.

### V8. Metric 계산 검증

**방법**: eventlog/statelog/rosbag parser 작성 → Metric 계산 → **Runner 제공 지표와 크로스체크**

**PASS**: 자체 계산값과 Runner 지표의 편차가 허용치(예: 5%) 이내, threshold 기반 verdict 생성, 실패 원인 분류 가능
**FAIL**: 필요한 필드 부족, timestamp 정렬 불가, actor ID 매칭 실패
**의사결정**: 편차 초과 시 정의 차이(TTC 산식, 필터링, 좌표계)를 규명하고, 규명 전까지 해당 Metric은 Runner 지표만 사용

---

## 13. 평가 기준 설계

### 13.1 평가 계층

```text
Execution Validation → Scenario Behavior Validation → Driving Safety Validation
```

### 13.2 Execution Validation

| 평가항목 | PASS 기준 |
|---|---|
| Load | `.xosc` load 성공 |
| Map | target map load 성공 |
| MGeo | matching MGeo load 성공 |
| Spawn | Ego/NPC/Pedestrian 생성 성공 |
| Start | Scenario running 상태 진입 |
| Stop | StopTrigger 또는 Evaluation으로 종료 |
| Log | eventlog/statelog 생성 |
| [v1.1] Boundary | 경계 감지 신호 정상 수신 |

### 13.3 Scenario Behavior Validation

| 평가항목 | PASS 기준 |
|---|---|
| Trigger sequence | 정의된 순서대로 발생 |
| Action execution | 각 Action 완료 |
| Actor behavior | NPC/보행자 동작 정상 |
| Timing | 지정된 시간/위치 조건 만족 |
| Storyboard state | running → complete/end |
| Error log | critical error 없음 |

### 13.4 Driving Safety Validation

Collision, Min TTC, Min Safe Distance, Max Way-off Distance, Max Lateral/Longitudinal Acceleration, Speed Excess/Deficit, Timeout — **정본은 Runner 제공 지표(Decision 5).**

### 13.5 Built-in과 External 평가의 차이

| 구분 | Built-in | External / Autoware |
|---|---|---|
| 목적 | Scenario 자체 검증 | 자율주행 알고리즘 검증 |
| Ego 제어 | Scenario Runner | 외부 알고리즘 |
| 주요 실패 원인 | 시나리오/지도/Trigger | localization/planning/control |
| 평가 의미 | 기준선 | ADS 성능 |
| 비교 대상 | 반복 실행 편차 | Built-in 대비 성능 차이 |

### 13.6 [v1.1 신규] 판정 3분류와 재현성 기준 운영

**판정은 PASS / FAIL / INCONCLUSIVE 3분류로 한다.**

| 판정 | 조건 |
|---|---|
| PASS | 모든 Metric이 threshold 만족, 데이터 무결성 정상 |
| FAIL | 하나 이상의 Metric이 threshold 위반 |
| INCONCLUSIVE | Metric 계산 불가(필드 부족, 파싱 실패), 크로스체크 편차 초과, 경계 감지 실패, 로그 유실 |

INCONCLUSIVE를 FAIL과 구분하는 이유: FAIL은 "시나리오/시스템이 기준을 못 지켰다"이고 INCONCLUSIVE는 "평가 자체가 성립하지 않았다"이다. 이 둘을 섞으면 회귀시험 통계가 오염된다.

**재현성 기준은 실측 캘리브레이션으로 산정한다** (V3 절차). 캘리브레이션 이전에는 임시로 다음을 참고값으로만 사용한다: duration ±5%, TTC/distance ±10%, Collision/판정 완전 동일. 이 값들은 근거 있는 기준이 아니므로 verdict에 사용하지 않는다.

---

## 14. Risk Register

| ID | Risk | 영향 | 가능성 | 심각도 | 대응 |
|---|---|---|---|---|---|
| R1 | Python API 연결 불안정 | Batch 자동화 불가 | Medium | High | API 연결 검증 자동화, 재연결 backoff |
| R2 | Map 자동 전환 실패 | Multi-Map Batch 제한 | Medium | High | Map 단위 batch 전략 (V4/V5) |
| R3 | SIM Headless 미지원 | CI/CD 제한 | High | Medium | GUI 최소화 운영으로 우회 |
| R4 | eventlog/statelog 정보 부족 | Metric 계산 제한 | Medium | High | 3원 소스 전략 (rosbag + API polling) |
| R5 | ROS2 topic 이름/타입 변경 | Logger 깨짐 | Medium | Medium | topic discovery + schemas/topics.json 버전 관리 |
| R6 | MGeo/Map 불일치 | 시나리오 실패 | Medium | High | MGeo validation test (V6) |
| R7 | 반복 실행 편차 큼 | 기준선 신뢰도 저하 | Medium | High | 실측 캘리브레이션 + sync mode 검증 (R12 연계) |
| R8 | Actor 잔존 | 다음 시나리오 오염 | Medium | High | **delete_all_actors 표준 cleanup + is_ignore_init_ego (해소 경로 확정)** |
| R9 | Autoware adapter 필요 | External 평가 지연 | High | Medium | Built-in MVP 이후 별도 WBS |
| R10 | 로그 용량 증가 | 저장소 문제 | High | Medium | retention policy, topic 선별 기록 |
| **R11** | **[v1.1] Runner 클라이언트 Qt 의존** | 서버/CI 실행 제약 | Medium | Medium | Phase 0 실험, Adapter 프로세스 격리, QCoreApplication/xvfb 대안 |
| **R12** | **[v1.1] Sync Mode의 ROS2 미지원 가능성** | 재현성 최후 수단 상실 | Medium | High | V3에서 실측, 불가 시 통계적 기준선 운영으로 전환 |
| **R13** | **[v1.1] 시나리오 경계 감지 불가/불안정** | artifact 분리 불가 | Medium | **High** | V1.5 신호 조합 실험, 최후: 시나리오당 1-batch 분해 |
| **R14** | **[v1.1] API 문서-실동작 불일치** | 구현 재작업 | High | Medium | Phase 0 api_contract.md 실측 확정, 버전별 smoke test |
| **R15** | **[v1.1] Runner-rosbag 시간 기준 불일치** | Metric 크로스체크 불가 | Medium | Medium | V7에서 sim/wall 기준 확정, offset을 metadata에 기록 |

---

## 15. PM 관점의 핵심 의사결정

### Decision 1. Autoware보다 Built-in을 먼저 한다.

Autoware를 먼저 붙이면 실패 원인이 과도하게 많아진다. Built-in은 시나리오 품질과 평가 가능성을 검증하는 기준선이다. **Phase 1~4는 Built-in 중심, External/Autoware는 Phase 6 이후.**

### Decision 2. 완전 Headless보다 API Batch를 먼저 한다.

Headless 지원 여부는 미확정이나 Python API Batch는 공식 기능이다. **GUI 최소화 + Python API + 자동 로깅이 1차 목표. Headless는 별도 R&D(단, R11에 따라 SIM Headless와 클라이언트 Qt 의존을 분리 검토).**

### Decision 3. 결과 저장 체계를 먼저 고정한다.

자동화는 실행보다 결과 추적성이 중요하다. 표준 artifact:

```text
metadata.json / eventlog.csv / statelog.csv / rosbag/
api_poll.jsonl(옵션) / metrics.csv / verdict.json / report.html / manifest.sha256
```

### Decision 4. Map 자동 전환은 반드시 검증 후 설계에 반영한다.

공식 문서에 자동 로드 설명은 있으나 API에 map control 함수는 없다. **Multi-Map Batch를 가정하지 않고 V4/V5 결과로 운영 전략을 결정한다.**

### Decision 5. [v1.1 신규] Metric 정본은 Scenario Runner 제공 지표로 한다.

**이유**

Runner가 이미 TTC, Safe Distance 등을 계산·제공하는데 Metric Engine이 statelog에서 재계산하면, TTC 산식·필터링·좌표계 차이로 두 값이 어긋나는 순간 "어느 쪽이 진실인가" 문제가 발생한다. 벤더 지표는 벤더 문서와 함께 근거를 제시할 수 있어 증적 방어력도 높다.

**결론**

```text
정본(source of truth): Scenario Runner 제공 지표
자체 계산: 크로스체크 및 Runner가 제공하지 않는 지표(예: lane offset 시계열)에만 사용
크로스체크 편차 초과 시: 해당 run은 INCONCLUSIVE, 원인 규명 전 자체 계산값을 verdict에 사용 금지
```

### Decision 6. [v1.1 신규] 경계 감지가 확정되기 전에는 Phase 2 이후를 착수하지 않는다.

**이유**

per-scenario 이벤트가 API에 없으므로 경계 감지는 추정 기반이다. 이것이 불안정하면 rosbag 분리, artifact 매핑, Metric의 시나리오 귀속이 전부 오염된다. **V1.5는 게이트(gate)다.**

---

## 16. 초기 구현 제안

### 16.1 Repository 구조

```text
morai_eval_framework/
  README.md
  api_contract.md              # [v1.1] Phase 0 실측 계약
  VERSIONS.lock
  configs/
    env.yaml
    topics.yaml
    metrics.yaml
    thresholds.yaml            # 캘리브레이션 버전 포함
    error_codes.yaml           # [v1.1] 오류 분류 체계
  schemas/                     # [v1.1] 실측 스키마
    statelog_schema.json
    eventlog_schema.json
    topics.json
  suites/
    builtin_kcity_smoke.yaml
    builtin_repro_calibration.yaml   # [v1.1] N=20 캘리브레이션 suite
    builtin_multimap_validation.yaml
  scenarios/
    KCity/
    Pangyo/
  src/
    morai_eval/
      __init__.py
      orchestrator.py          # 상태머신 + watchdog
      boundary_detector.py     # [v1.1] 경계 감지
      scenario_runner_client.py  # Adapter (Qt 격리 대상)
      artifact_manager.py
      rosbag_recorder.py
      api_poller.py            # [v1.1] fallback 소스
      log_parser.py
      metric_engine.py
      verdict.py
      report_generator.py
      errors.py                # [v1.1] 오류 코드 정의
  tests/                       # [v1.1] Framework 자체 테스트 (22장)
    unit/
      test_log_parser.py
      test_metric_engine.py
      test_boundary_detector.py
      test_verdict.py
    fixtures/
      sample_eventlog.csv
      sample_statelog.csv
      golden_metrics.csv
    integration/
      test_smoke_with_sim.py   # SIM 필요, 마커로 분리
  scripts/
    run_builtin_suite.sh
    record_rosbag.sh
    collect_logs.sh
    make_manifest.sh           # [v1.1] SHA256 manifest
  results/
  docs/
```

### 16.2 test_suite.yaml 예시

```yaml
suite_id: builtin_kcity_smoke
controller_mode: BuiltIn
sync_mode: false
is_ignore_init_ego: true        # [v1.1] 기본값: 상태 이월 차단
cleanup_between_scenarios: true # [v1.1] delete_all_actors 호출
num_iterations: 1
timeout_sec: 120                # 시나리오당 watchdog
boundary_detection:
  poll_interval_ms: 200
  signals: [scenario_name, storyboard_state]  # V1.5 결과로 확정

scenarios:
  - id: Scenario_CCRB_001
    map_id: R_KR_PG_K-City
    file: scenarios/KCity/Scenario_CCRB_001.xosc
    expected:
      collision: false
      max_duration_sec: 60
      min_ttc_sec: 1.5

  - id: Scenario_CCRB_002
    map_id: R_KR_PG_K-City
    file: scenarios/KCity/Scenario_CCRB_002.xosc
    expected:
      collision: false
      max_duration_sec: 60
```

### 16.3 실행 흐름

```text
 1. suite yaml 로드 + 스키마 검증
 2. VERSIONS.lock / api_contract 버전 확인
 3. 결과 폴더 생성 (tmp 접미사)
 4. Scenario Runner API 연결 확인 (retry + backoff)
 5. ROS2 topic discovery (schemas/topics.json 대조)
 6. [시나리오 루프]
    a. rosbag record 시작 (subprocess)
    b. 경계 감지기 arm
    c. batch 실행 or 다음 시나리오 대기
    d. 상태머신 polling (RUNNING → COMPLETE/ERROR/TIMEOUT)
    e. rosbag graceful stop (SIGINT)
    f. delete_all_actors (cleanup_between_scenarios=true 시)
    g. eventlog/statelog 매핑·복사
    h. metadata.json 기록
    i. tmp → 정식 폴더 rename (원자성)
 7. metrics 계산 (Runner 지표 정본 + 크로스체크)
 8. verdict 생성 (PASS/FAIL/INCONCLUSIVE)
 9. manifest.sha256 생성
10. suite report 생성
```

### 16.4 시나리오 간 표준 cleanup 시퀀스 [v1.1 신규]

```text
scenario N 종료 감지
  → rosbag stop 확인 (프로세스 종료 대기, 최대 10s)
  → delete_all_actors() 호출
  → get_states_vehicle/object로 잔존 0 확인 (최대 3회 재시도)
  → 잔존 시: WARN 기록 + 다음 시나리오 verdict에 CONTAMINATION_RISK 플래그
  → scenario N+1 진행
```

---

## 17. 단기 실행 계획 (Sprint)

### Sprint 0. API 계약 검증 [v1.1 신설]

**목표**: Phase 0 완료. Qt 의존성, 함수 시그니처, callback 동작을 실측으로 확정.

**작업**: QApplication 유/무 실험, 함수별 호출·반환 기록, `api_contract.md` 작성, VERSIONS.lock 생성

**완료 기준**: api_contract.md 리뷰 완료, Adapter 프로세스 구조(격리 여부) 확정

### Sprint 1. Built-in API Smoke Test + 경계 감지 프로토타입

**목표**: Python API로 Built-in 단일 시나리오 실행 + V1.5 경계 감지 신호 실험

**작업**: API 연결 스크립트, 단일 `.xosc` 실행, 경계 후보 신호 동시 기록, eventlog/statelog 위치 확인, metadata 저장

**완료 기준**: 단일 시나리오 1회 실행 성공, 로그 자동 수집 성공, **경계 감지 신호 조합 확정 (게이트)**

### Sprint 2. Batch + Artifact Manager

**목표**: 복수 시나리오 순차 실행 + 표준 구조 저장

**작업**: test_suite.yaml, 결과 디렉터리(원자적 쓰기), 시나리오별 metadata, 로그 매핑·복사, cleanup 시퀀스(16.4), manifest 생성

**완료 기준**: 3개 이상 시나리오 batch 실행, 시나리오별 결과 폴더 정확 매핑, 실패 주입 시에도 폴더 오염 없음

### Sprint 3. Metric Engine v1 + 스키마 인벤토리

**목표**: Runner 지표 정본 수집 + statelog 크로스체크

**작업**: schema_inventory.py, eventlog/statelog parser, Runner 지표 파싱, threshold 적용, metrics.csv/verdict.json 생성, **parser 단위 테스트 + golden file 테스트(22장)**

**완료 기준**: PASS/FAIL/INCONCLUSIVE 자동 판정, 크로스체크 편차 보고, 실패 원인 오류 코드 분류

### Sprint 4. Rosbag Integration + 시간 정합

**목표**: rosbag 저장 및 평가 활용, 시간 기준 확정

**작업**: topic discovery, rosbag recorder subprocess wrapper, 경계 연동 시작/종료, sim/wall clock offset 측정·기록

**완료 기준**: Ego/Object 상태 기록, Runner 로그와 시간 정합 확인(R15 해소), bag 재생 검증

### Sprint 5. 재현성 캘리브레이션 + Multi-Map Validation

**목표**: N=20 반복으로 threshold 캘리브레이션(V3) + Map 자동 전환 판단(V4/V5)

**작업**: 캘리브레이션 suite 실행, thresholds.yaml 산정, is_ignore_init_ego/cleanup 매트릭스 실험, map transition report

**완료 기준**: 근거 있는 threshold 확정, Multi-Map 운영 전략 확정

---

## 18. 성공 기준

| 구분 | 성공 기준 |
|---|---|
| 자동 실행 | Python API로 Built-in Batch 실행 |
| 경계 감지 | [v1.1] 시나리오 시작/종료 오탐·미탐 없이 감지, artifact 정확 귀속 |
| 자동 로깅 | eventlog/statelog/metadata/rosbag 저장 + manifest |
| 자동 평가 | Runner 지표 정본 + 크로스체크, metrics.csv/verdict.json 생성 |
| 판정 품질 | [v1.1] PASS/FAIL/INCONCLUSIVE 3분류, 오류 코드 분류 |
| 반복성 | 실측 캘리브레이션 기반 기준으로 재현성 판정 |
| 추적성 | scenario, map, version, api_contract, log, metric 연결 |
| 확장성 | External/Autoware로 controller mode 확장 가능 |
| 운영성 | 실패 시 원인 분류와 로그 보존, batch 전체 중단 없음 |
| 신뢰성 | [v1.1] Framework 자체가 단위/골든 테스트로 검증됨 |

---

## 19. 최종 제안

```text
 1. API 계약 검증 (Qt 의존성 포함)          ← [v1.1 추가]
 2. Scenario Runner 실행 안정화
 3. Built-in 단일 시나리오 API 실행
 4. 시나리오 경계 감지 방법 확정 (게이트)     ← [v1.1 추가]
 5. Built-in Batch 실행
 6. 로그 및 artifact 표준화 (+manifest)
 7. 로그 스키마 인벤토리                     ← [v1.1 추가]
 8. Metric Engine 구축 (Runner 지표 정본)
 9. 반복 실행 재현성 캘리브레이션
10. 지도 자동 전환 검증
11. Multi-Map Batch 전략 확정
12. HTML Report 자동 생성
13. External/Autoware 연동
```

전략적 원칙은 v1.0과 동일하다.

> **Autoware 성능평가 이전에, 시나리오 자체가 평가 가능한 자산인지 Built-in으로 먼저 검증한다.**

여기에 v1.1의 원칙을 추가한다.

> **API 문서를 믿지 말고 계약을 실측하라. 경계 감지가 확정되기 전에 파이프라인을 쌓지 마라. Metric의 진실은 하나만 두어라.**

```text
Built-in 실패:            → Scenario / Map / MGeo / Trigger 문제
Built-in 성공, External 실패: → External controller / ROS2 / Adapter / Autoware 문제
평가 자체가 불성립(INCONCLUSIVE): → Framework / 로깅 / 경계 감지 문제 ← [v1.1] 이 축을 분리
```

1차 산출물은 "Autoware 평가 시스템"이 아니라 **Scenario Quality Baseline System**이다.

---

## 20. 참고한 공식 문서 및 근거

- MORAI Scenario Runner Python API
  - `set_scenario_config()`, `start_batch_scenario()`, `controller_mode`, `num_iterations`, `sync_mode`
  - [v1.1] `delete_all_actors()`, `is_ignore_init_ego`, `get_states_vehicle/pedestrian/object`, `set_weather()`, `set_time_of_day()`, `get_available_map()` 확인. `set_map()` 부재 확인. 예제 코드의 QApplication 의존 구조 확인.
  - https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/python-api
- MORAI Scenario Runner 개요 — `.xosc` 로드, gRPC 통신, MGeo 기반 정의, Trigger/Action 구조
  - https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/-2
- MORAI Scenario Runner 시뮬레이션 수행 — 제어 모드, 대상 지도 자동 로드, Batch Simulation
  - https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/-1
- MORAI Scenario Runner 시뮬레이션 결과 확인 — Evaluation Index, eventlog/statelog 저장 경로
  - https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/-6
- MORAI SIM: Drive 26.R1 — ROS2 Native 통신 인터페이스, 메시지, 설정 UI
  - https://help-morai-sim.scrollhelp.site/ko/morai-sim-drive/26.R1/
- [v1.1] MORAI SIM: Drive 26.R1 Synchronous Mode — **"현재 ROS에서만 지원" 명시** (R12 근거)
  - https://help-morai-sim.scrollhelp.site/ko/morai-sim-drive/26.R1/synchronous-mode
- MORAI SIM Replay - Rosbag — Ego 주행 데이터 저장·재현
  - https://help-morai-sim.scrollhelp.site/ko/morai-sim-drive/26.R1/replay-rosbag

---

## 21. 구현 엔지니어링 설계 [v1.1 신설]

> 이 장은 "무엇을 만들 것인가"가 아니라 "어떻게 만들어야 깨지지 않는가"를 다룬다.

### 21.1 프로세스 토폴로지

```text
[Orchestrator 프로세스]  ← 순수 Python, Qt 없음
   │  (subprocess / JSON-lines IPC)
   ├── [Runner Adapter 프로세스]  ← Python API + (필요 시) QCoreApplication
   │        │ gRPC
   │        └── Scenario Runner ── MORAI SIM
   ├── [rosbag2 record 프로세스]  ← 시나리오 경계마다 spawn/SIGINT
   └── [API Poller 스레드/프로세스] ← 옵션, fallback 소스
```

**설계 근거**

- Qt 의존성(R11)이 확인되더라도 Adapter 프로세스 내부에 국한된다. Orchestrator는 어떤 환경에서도 순수 Python으로 동작한다.
- Adapter가 hang/crash해도 Orchestrator의 watchdog이 프로세스를 kill하고 batch를 계속 진행할 수 있다(NFR-06). 같은 프로세스 안에서 API가 hang하면 watchdog 자체가 죽는다.
- rosbag은 반드시 별도 프로세스다. Python 내 recording은 GIL과 직렬화 부하로 고주파 topic에서 drop이 발생한다.

### 21.2 Run Lifecycle 상태머신

Orchestrator의 핵심은 아래 상태머신이며, 모든 전이는 `state_machine.log`에 timestamp와 함께 기록한다.

```text
IDLE
 → CONNECTING        (API 연결, retry ≤3, exponential backoff 1/2/4s)
 → PREPARING         (결과 폴더 tmp 생성, topic discovery, rosbag arm)
 → LAUNCHING         (batch/scenario 시작 요청)
 → WAIT_SCENARIO_START  (경계 감지: 시작 신호 대기, timeout T_start=30s)
 → SCENARIO_RUNNING     (polling 200ms: storyboard state, sim time, 경계 신호)
 → SCENARIO_ENDING      (종료 신호 감지, 로그 flush 대기 grace 5s)
 → COLLECTING           (rosbag stop, 로그 매핑, cleanup 시퀀스 16.4)
 → EVALUATING           (metric, verdict)
 → COMMITTED            (tmp → rename, manifest)
 → (다음 시나리오) WAIT_SCENARIO_START ...
 → SUITE_DONE

이상 전이:
 SCENARIO_RUNNING --(timeout_sec 초과)--> ABORTING (skip/stop 호출) → COLLECTING(부분) → verdict=FAIL(ERR_TIMEOUT)
 임의 상태 --(Adapter 무응답 >15s)--> KILLING (프로세스 kill) → RECOVERING (재연결) → 다음 시나리오
 RECOVERING 실패 ×2 → SUITE_ABORT (전체 중단, 지금까지 결과는 보존)
```

**구현 포인트**

- 경계 신호는 V1.5에서 확정한 **2개 이상 신호의 AND/OR 조합**을 사용하고, 단일 신호의 glitch(예: polling 사이 값 요동)에 대비해 2회 연속 관측으로 debounce한다.
- `timeout_sec`은 suite 레벨 기본값 + 시나리오별 override. 산정 근거는 "expected max_duration × 2 + 로드 마진 30s".
- 시나리오 skip 후에는 반드시 cleanup 시퀀스를 수행한다. skip이야말로 actor 잔존이 가장 잘 발생하는 경로다.

### 21.3 시간 정합 설계 (R15)

세 개의 시간축이 존재한다: wall clock(OS), sim time(/clock), Runner 로그 timestamp(기준 미확정).

```text
정합 절차:
1. 시나리오 시작 감지 시점에 (wall, sim) 쌍을 기록 → sim_clock_offset_sec
2. V7에서 Runner statelog의 timestamp가 sim/wall 어느 쪽인지 실측 판정
3. Metric Engine은 모든 소스를 sim time으로 정규화한 뒤 계산
4. rosbag은 --use-sim-time 여부를 topics.yaml에 명시
```

크로스체크(Decision 5)는 시간 정규화가 된 뒤에만 의미가 있다. 시간 기준이 미확정인 동안 크로스체크 편차는 verdict에 사용하지 않는다.

### 21.4 오류 분류 체계 (Error Taxonomy)

`verdict.json`의 `error_code`는 아래 체계를 따른다. 감지 규칙(로그 패턴, API 반환값)은 `configs/error_codes.yaml`에 두고, V6 등 실험에서 관측된 실제 패턴을 계속 등록한다.

| 코드 | 의미 | 귀속 |
|---|---|---|
| ERR_CONNECT | gRPC 연결 실패 | Framework/환경 |
| ERR_LOAD_XOSC | 시나리오 파일 로드 실패 | Scenario |
| ERR_LOAD_MGEO | MGeo 로드/불일치 | Map/MGeo |
| ERR_MAP_SWITCH | 지도 자동 전환 실패 | SIM/Runner |
| ERR_SPAWN | Actor 생성 실패 | Scenario/Map |
| ERR_TRIGGER | Trigger 미발생/오발생 | Scenario |
| ERR_TIMEOUT | watchdog timeout | Scenario/SIM |
| ERR_CRASH_SIM | SIM 프로세스 이상 종료 | SIM |
| ERR_CRASH_ADAPTER | Adapter 무응답/종료 | Framework |
| ERR_LOG_MISSING | eventlog/statelog 미생성 | Runner/Framework |
| ERR_BAG_FAIL | rosbag 기록 실패 | Framework/ROS2 |
| ERR_BOUNDARY | 경계 감지 실패 | Framework |
| ERR_CONTAMINATION | actor 잔존/상태 이월 감지 | Framework/Runner |
| ERR_METRIC_PARSE | Metric 계산 불가 | Framework |
| ERR_CROSSCHECK | 정본-자체계산 편차 초과 | Framework/정의 차이 |

이 분류가 있어야 FR-12(Failure 분석)와 19장의 원인 분리 원칙("Built-in 실패 vs External 실패 vs 평가 불성립")이 자동화된다.

### 21.5 데이터 무결성과 원자성 (NFR-09)

- run 폴더는 `run_001.tmp`로 생성하고 모든 artifact가 완결된 뒤 `run_001`로 rename한다. 도중 crash 시 `.tmp` 폴더는 "미완결"로 자동 식별된다.
- metadata.json, verdict.json은 임시 파일 작성 후 `os.replace()`로 교체한다.
- Runner의 `logs_scenario_runner/` 폴더에서 run 폴더로의 매핑은 **파일명(수행시각_지도_시나리오)과 경계 감지 timestamp의 이중 대조**로 수행하고, 매핑 모호 시 ERR_LOG_MISSING 처리한다(다른 run의 로그를 잘못 귀속시키는 것이 유실보다 나쁘다).
- manifest.sha256은 rename 직전에 생성한다.

### 21.6 로그 용량 운영 (R10)

- rosbag은 `topics.yaml`의 화이트리스트만 기록한다(전체 record 금지). 센서 raw(카메라/라이다)는 Built-in 기준선 평가에 불필요하므로 기본 제외.
- retention: PASS run은 rosbag 30일 후 삭제(metrics/verdict/manifest는 영구), FAIL/INCONCLUSIVE run은 원본 전체 보존.
- suite 시작 전 디스크 여유 확인, 임계 미만 시 suite 시작 거부.

---

## 22. Framework 자체 검증 전략 [v1.1 신설]

> 평가 도구가 틀리면 모든 평가 결과가 틀린다. "테스트 도구를 테스트"하는 전략을 명시한다.

### 22.1 테스트 피라미드

```text
        [E2E]  실제 SIM + Runner smoke suite (nightly, 3 시나리오)
       [통합]   Adapter ↔ mock gRPC / 파일시스템 실제 사용
      [단위]    parser, metric, verdict, boundary detector, error 분류
```

### 22.2 단위 테스트 (SIM 불필요, CI에서 상시 실행)

| 대상 | 방법 |
|---|---|
| log_parser | 실측 캡처한 eventlog/statelog를 fixture로 고정, 컬럼 결측·인코딩 깨짐·빈 파일 케이스 포함 |
| metric_engine | **golden file 테스트**: 손으로 검산한 기대 metrics.csv와 비트 단위 비교. 수치는 허용 오차(1e-6) 비교 |
| verdict | threshold 경계값(정확히 같은 값, ±ε) 케이스, INCONCLUSIVE 분기 전수 |
| boundary_detector | 신호 시퀀스를 시뮬레이트한 타임라인 fixture로 오탐/미탐/디바운스 검증 |
| errors | 로그 패턴 → error_code 매핑 회귀 테스트 |

### 22.3 통합 테스트

- **Mock Adapter**: Runner API와 동일한 인터페이스를 갖는 가짜 Adapter가 정해진 시나리오(정상 종료, timeout, 중간 crash, 로그 미생성)를 재생 → Orchestrator 상태머신의 모든 이상 전이를 SIM 없이 검증한다.
- **Fault Injection**: batch 도중 Adapter 프로세스 kill, rosbag 프로세스 kill, 디스크 가득참(quota)을 주입하여 NFR-06(격리)과 NFR-09(원자성)를 검증한다.

### 22.4 E2E Smoke (SIM 필요)

- 3개 시나리오(정상 2 + 의도적 FAIL 1)의 고정 suite를 nightly로 실행한다.
- 판정 기대값이 고정되어 있으므로(PASS/PASS/FAIL), Framework 회귀가 발생하면 즉시 드러난다.
- Runner/SIM 버전 업그레이드 시 이 suite + api_contract smoke를 먼저 통과해야 운영 suite를 돌린다(R14 대응).

### 22.5 Metric 정합성 검증 (V8과 연동)

- Runner 지표 vs 자체 계산의 편차 분포를 캘리브레이션 suite(N=20)에서 수집한다.
- 편차가 체계적(항상 한쪽이 큼)이면 정의 차이(TTC 산식 등)를 규명하여 문서화하고, 무작위적이면 시간 정합(21.3)부터 재점검한다.

### 22.6 수용 기준

- 단위 테스트 커버리지: parser/metric/verdict/boundary 모듈 라인 커버리지 ≥ 85%
- Mock 기반 상태머신 이상 전이 케이스: 21.2에 정의된 전이 전수 통과
- Golden file: Runner 버전 변경 외 사유로 diff 발생 시 머지 차단

---

*끝. 본 문서는 v1.0의 전략 골격을 유지하되, 공식 문서 재대조(C1~C6)와 구현·검증 관점(C7~C12)을 반영한 개정본이다.*
