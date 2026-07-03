# AVStack 통합 로드맵 v1

| 항목 | 내용 |
|---|---|
| 문서명 | AVStack 통합 로드맵 (운영가이드 Stage × 설계노트 Phase 정렬) |
| 버전 | v1.0 |
| 작성일 | 2026-07-03 |
| 위치 | `~/avstack-control/runbooks/integrated_roadmap.md` |
| 상위 문서 | AVStack 환경설정 운영가이드, MORAI SIM 자동화 평가 Framework 설계노트 v1.1 |
| 성격 | 두 로드맵의 정렬 기준 문서 (single source of truth) |

---

## 1. 배경과 목적

현재 프로젝트에는 두 개의 로드맵이 존재한다.

1. **AVStack 환경설정 운영가이드** — Stage 00~08. 환경 구축과 Autoware 연동까지의 실행 트랙.
2. **MORAI SIM 자동화 평가 Framework 설계노트 v1.1** — Phase 0~7 / Sprint 0~5. Built-in 기준선 자동 평가 프레임워크 구축 트랙.

두 문서를 그대로 두면 Stage 05 통과 후 곧바로 Autoware(Stage 06)로 진입하게 되어, 설계노트의 핵심 원칙(Decision 1: Built-in 기준선 우선, Decision 6: 경계 감지 게이트)과 충돌한다. 본 문서는 두 트랙을 하나의 Stage 체계로 정렬하고, 각 Stage의 Gate 기준을 확정한다.

**정렬 원칙**

- Autoware(Stage 06) 진입 전에 Built-in 자동화 파이프라인(설계노트 Phase 0~3)을 완성한다.
- RTX 3050 4GB VRAM 제약상, Autoware 없이 완성 가능한 자산(평가 프레임워크)을 먼저 끝낸다.
- 기존 Gate 원칙(records/*.tsv 기록, 원본 로그 보존)을 신설 Stage에도 동일 적용한다.

---

## 2. 현재 상태 (2026-07-03 기준)

| 항목 | 상태 |
|---|---|
| Stage 00 Remote GPU | PASS |
| Stage 01 MORAI Launcher/SIM Standalone | PASS (기록 반영 필요) |
| Stage 02 Scenario Runner Window | PASS (기록 반영 필요, AVS-001 해소) |
| Stage 03 MORAI Example XOSC Built-in | PASS (기록 반영 필요) |
| AVS-001 (Runner 창 미표시) | RESOLVED (resolution 기록 및 runbook화 필요) |
| avstack-control 저장소 | 초기화 완료, records/scripts/runbooks 운영 중 |

---

## 3. 통합 Stage 로드맵

| Stage | 이름 | 내용 | 설계노트 매핑 | 상태 |
|---:|---|---|---|---|
| 00 | Remote GPU Environment | NVIDIA PRIME offload 확인 | — | PASS |
| 01 | MORAI Launcher/SIM Standalone | SIM 단독 실행 | Phase 0 일부 | PASS |
| 02 | Scenario Runner Window | Runner 창 표시 | Phase 0 일부 | PASS |
| 03 | Example XOSC Built-in (GUI) | 예제 시나리오 GUI 실행 | Phase 0 일부 | PASS |
| **03.5** | **Python API 계약 검증** | Qt 의존성, 함수 시그니처 실측, api_contract.md | **Sprint 0 (V1)** | TODO ← 다음 |
| **03.7** | **API 단일 실행 + 경계 감지** | API로 단일 xosc 실행, 경계 감지 신호 확정 | **Sprint 1 (V2, V1.5)** | TODO, **게이트** |
| 04 | ROS2 Humble Host | ROS2 기본 통신 | — | TODO (03.5와 병렬 가능) |
| 05 | MORAI ROS2 Native Topic | topic 확인 + sim/wall clock offset 측정 | V7 준비 | TODO |
| **05.5** | **Built-in Batch 자동화 파이프라인** | Batch 실행 + artifact 표준화 + Metric Engine | **Sprint 2~3 (Phase 1~3)** | TODO, **Autoware 전 필수** |
| **05.7** | **재현성 캘리브레이션 + Multi-Map 검증** | N=20 캘리브레이션, Map 자동 전환 판단 | **Sprint 4~5 (V3~V5)** | TODO |
| 06 | Autoware Base | Autoware 실행 기반 | Phase 6 준비 | 보류 (05.7 통과 후) |
| 07 | MORAI-Autoware Topic Mapping | topic/message/frame 정합 | Phase 6 | 보류 |
| 08 | Scenario Runner External Closed-loop | External mode 연동 | Phase 6 | 보류 |

**게이트 규칙 (신설분)**

- Stage 03.7의 경계 감지 확정 전에는 Stage 05.5(파이프라인 구축)를 착수하지 않는다 (설계노트 Decision 6).
- Stage 05.5 통과 전에는 Stage 06(Autoware)을 착수하지 않는다 (설계노트 Decision 1).
- Docker 도입 판단은 기존대로 Stage 05 통과 후로 유지하되, 실제 설치는 Stage 06 착수 시점으로 미룬다.

---

## 4. Stage 03.5: Python API 계약 검증 (상세)

**목적**: Scenario Runner Python API의 실제 동작 계약을 실측으로 확정한다. 문서를 믿지 않고 계약을 실측한다 (설계노트 5.14, R14).

**선행 조건**: Stage 03 PASS (완료)

**작업 항목**

1. Python API 자산 위치 확인: 설치 폴더에서 API 모듈/예제 검색
   ```bash
   find ~/Downloads/MoraiLauncher_Lin -iname "*python*" -o -iname "*api*" -o -iname "*.whl" 2>/dev/null
   find ~/avstack/morai -iname "*python*" -o -iname "*api*" 2>/dev/null
   ```
2. Qt 의존성 실험 (설계노트 6.6):
   - 실험 1: QApplication 없이 client 생성 → `is_connected()` → 결과 기록
   - 실험 2 (실험 1 실패 시): QCoreApplication으로 대체 → 결과 기록
3. 기본 함수 smoke test: `is_connected()`, `get_simulator_version()`, `get_available_map()`
4. 문서-예제 불일치 함수(`get_storyboard_element` 등) 실제 시그니처 확인
5. 산출물 작성: `api_contract.md`, `VERSIONS.lock` 갱신 (Runner 버전 + smoke 결과)

**PASS 기준**

- API 연결 성공, 버전/Map 목록 반환
- QApplication 필요 여부 확정 (필요 시 Adapter 프로세스 격리 설계 채택 기록)
- `api_contract.md` 작성 및 커밋

**FAIL 시**: gRPC 포트/실행 순서 재점검, Runner 버전 확인, 이슈 등록 (AVS-00X)

---

## 5. Stage 03.7: API 단일 실행 + 경계 감지 (상세)

**목적**: API로 Built-in 단일 시나리오를 실행하고(V2), 시나리오 경계 감지 신호 조합을 확정한다(V1.5). **이 Stage는 게이트다.**

**선행 조건**: Stage 03.5 PASS

**작업 항목**

1. 예제 `.xosc` 1개를 `ControllerFrom.BuiltIn`, `num_iterations=1`로 API 실행
2. eventlog/statelog 생성 위치·파일명 규칙 확인
3. 2개 시나리오 batch를 실행하며 경계 후보 신호를 100~500ms 주기로 동시 기록:
   - S1. scenario name 변화 / S2. storyboard 상태 전이 / S3. sim time 리셋 / S4. eventlog 파일 생성 감지 / S5. batch callback
4. 감지 신호 조합 확정 후 `api_contract.md`에 기록

**PASS 기준**

- 단일 시나리오 API 실행 성공, 로그 생성 확인
- 최소 2개 신호 조합으로 시나리오 시작/종료를 오탐·미탐 없이 감지, 지연 < 1초

**FAIL 시 대응**: 파일시스템 watch(S4) 주 신호 전환 → 최악의 경우 시나리오당 1-batch 분해 (설계노트 V1.5)

---

## 6. Stage 05.5 / 05.7 요약

- **05.5**: `test_suite.yaml` 기반 Batch 실행, run별 결과 폴더(원자적 쓰기), metadata/manifest, rosbag 경계 연동, Runner 지표 정본 + 크로스체크 Metric Engine, PASS/FAIL/INCONCLUSIVE 3분류. 상세는 설계노트 Phase 1~3, 16장, 21장.
- **05.7**: N=20 반복으로 threshold 캘리브레이션(V3), is_ignore_init_ego/cleanup 매트릭스, Map 자동 전환 검증(V4/V5), Multi-Map 운영 전략 확정. 상세는 설계노트 Sprint 5.

---

## 7. 저장소 구조 결정 (ADR-008)

**결정**: 평가 프레임워크 코드(`morai_eval_framework`)는 avstack-control과 **별도 저장소**로 관리한다.

**이유**

- avstack-control은 환경·기록·절차 관리 저장소로 권한 정책(curl/apt deny 등)이 보수적이다.
- 프레임워크 개발은 pip 설치, pytest, CI가 필요하여 권한 모델이 다르다.
- 섞으면 두 저장소의 정체성과 Claude Code 권한 설정이 모두 어색해진다.

**연결 방식**

- avstack-control의 `records/stages.tsv` evidence 컬럼에 프레임워크 repo의 커밋 해시를 기록하여 추적성을 유지한다.
- 프레임워크 repo의 `VERSIONS.lock`·`api_contract.md`는 프레임워크 repo에 두되, Stage 판정 근거로 인용한다.

---

## 8. records 반영 지시 (Claude Code 작업 대상)

아래 항목을 TSV에 반영한다. 날짜·evidence 경로는 실제 값으로 채운다.

**stages.tsv 추가**

```text
01_morai_launcher  PASS  (SIM 단독 실행 확인 요약)  (원본 로그 경로)  Stage02
02_scenario_runner PASS  (Runner 창 표시 확인 요약)  (원본 로그 경로)  Stage03
03_example_xosc    PASS  (예제 xosc Built-in 실행 요약)  (원본 로그 경로)  Stage03.5
```

**issues.tsv 갱신**

- AVS-001: STATUS를 RESOLVED로, resolution 컬럼에 실제 해결 방법 기록

**decisions.tsv 추가**

```text
ADR-007  통합 로드맵 채택 (Stage 03.5/03.7/05.5/05.7 신설, Autoware는 05.7 이후)
ADR-008  평가 프레임워크는 별도 저장소로 분리
```

**runbooks 추가**

- `runbooks/avs-001_scenario_runner_window.md`: AVS-001 증상·원인·해결 절차 (재발 대비)
- `runbooks/integrated_roadmap.md`: 본 문서

**CLAUDE.md 갱신**

- "현재 상태" 절: Stage 03 PASS, 다음 Stage 03.5로 갱신
- "운영 규칙" 절에 추가: "Stage 03.7(경계 감지) 통과 전 파이프라인 구축 금지, Stage 05.7 통과 전 Autoware 작업 금지"

---

## 9. 참고 문서

- MORAI SIM 자동화 평가 Framework 설계노트 v1.1 (Phase/Sprint/V-검증 상세)
- AVStack 환경설정 운영가이드 (Stage 00~08 원본, TSV 기록 체계)
- MORAI Scenario Runner Python API: https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/python-api
