# PROJECT_STATUS — AVStack 자동화 평가 프레임워크

| 항목 | 내용 |
|---|---|
| 문서 성격 | **살아있는 마스터 인덱스** — 모든 세션의 시작점이자 종료점 |
| 위치 | `~/avstack-control/PROJECT_STATUS.md` (저장소 루트) |
| 스냅샷 기준일 | 2026-07-06 |
| 갱신 규약 | 매 세션 종료 시 갱신 (12장 인수인계 규약 참조) |

> **이 문서의 사용법**: 새 세션(사람 또는 Claude Code)은 이 문서를 가장 먼저 읽는다.
> 여기서 현재 상태·열린 스레드·다음 액션을 파악한 뒤, 필요한 상세는 3장 문서 지도를 따라간다.

---

## 1. 프로젝트 한 줄 정의

MORAI SIM 26.R1 + Scenario Runner를 실행 엔진으로 하는 **재현 가능한 시나리오 자동 평가 프레임워크** 구축. Built-in 기준선 우선, Autoware는 이후 확장 (설계노트 Decision 1).

## 2. 현재 상태 스냅샷 (2026-07-06)

### Stage 보드

| Stage | 이름 | 상태 | 비고 |
|---|---|---|---|
| 00~04 | Remote GPU ~ ROS2 Humble Host | **PASS** | 04까지 완료 |
| 03.5 | Python API 계약 검증 | **BLOCKED** | AVS-006 (sourcedefender) |
| 03.7 | API 단일 실행 + 경계 감지 (게이트) | 대기 | 03.5 종속 |
| 05 | MORAI ROS2 Native Topic | **FAIL/BLOCKED** | AVS-007 (ros2cs 예외 + rosbridge header.seq) |
| 05.5 / 05.7 | Batch 파이프라인 / 캘리브레이션 | 대기 | 03.7 게이트 종속 |
| 06~08 | Autoware | 보류 | 05.7 통과 후 (ADR-007) |

### 크리티컬 패스 진단

**양쪽 API 경로(Python API, ROS2 Native)가 모두 벤더 의존으로 차단된 상태.** 따라서 현재 진행 가능한 트랙은:

1. **SIM-불필요 트랙**: GUI 실행으로 확보한 eventlog/statelog 기반 로그 스키마 인벤토리 + parser/metric/verdict 단위·gol든 테스트 (설계노트 22장)
2. **진단 트랙**: AVS-007 계층 분리 진단 D1~D5 (사람 1분 GUI 세팅 필요)
3. **자율화 트랙**: GUI autopilot PoC + E안(API polling 승격) 아키텍처 재설계
4. **벤더 트랙**: 문의 2건(MORAI-001 AVS-007 / MORAI-002 AVS-006) **발송 완료(2026-07-06, CTO 커버 MORAI-004 + 기술상세 2건)** — SENT 동결·전이 행 반영. **다음 = 1차 회신 대기(~7/10), due 초과 시 리마인드**. MORAI-003(기능요청) 초안 대기. (vendor/ 체계 신설 완료)

### 열린 이슈 (요지)

| ID | 요지 | 상태 | 벤더 의존 |
|---|---|---|---|
| AVS-006 | Python API가 sourcedefender로 보호됨 — 지원 Python/설치 절차 불명 | BLOCKED | O |
| AVS-007 | ROS2 Native: ros2cs가 participant 생성 전 예외 / rosbridge: header.seq(ROS1 잔재) 충돌 | BLOCKED | O |

## 3. 문서 지도 (Document Map)

| 문서 | 위치 | 역할 | 상태 |
|---|---|---|---|
| **PROJECT_STATUS.md** | 루트 | 마스터 인덱스 (본 문서) | 살아있음 |
| 설계노트 v1.1 | `runbooks/framework_design_note_v1.1.md` | 프레임워크 설계 기준 (Phase/V-검증/21·22장) | v1.1 / **erratum 필요: 5.8** |
| 통합 로드맵 | `runbooks/integrated_roadmap.md` | Stage×Phase 정렬 정본 (ADR-007/008) | v1 (erratum 반영됨) |
| 운영가이드 | (원본 관리 위치) | 환경 구축 Stage 00~08 원 절차 | 유지 |
| AVS-007 진단 계획 | `runbooks/avs-007_layer_diagnosis.md` | D1~D5 실험 카드 + 판정 매트릭스 (스크립트 scripts/avs007_diag/) | 실행 대기 |
| AVS-007 native 분석 | `runbooks/avs-007_ros2_native_report.md` | ros2cs ABI/H1 반증 등 native 실측 분석 | 유지 |
| 완전 자율화 분석 | `runbooks/full_autonomy_analysis.md` | GUI 자동화 vs 아키텍처 우회(E안 채택) — 7장 구조 | 배치 완료 / PoC 대기 |
| 문서·벤더 관리 규약 | `runbooks/doc_and_vendor_management.md` | 문서체계·벤더 커뮤니케이션 규약(2층키) | v1.2 |
| 저장소 경계 | `runbooks/repo_boundaries.md` | 5리포 별칭 체계·경계(ADR-011) | v1.1 |
| MORAI 문의/발송본 | `vendor/morai/{OUTBOX,SENT}/` | AVS-007/006 문의 + CTO 커버(004) | **발송 완료(SENT, 2026-07-06)** |
| 세션 리포트 | `reports/YYYY-MM-DD_session.md` | 세션별 완료·교훈 기록 (2026-07-03 이관 완료) | 운영 중 |
| records/*.tsv | `records/` | 불변 원장 (stages/issues/decisions/commands/vendor_comms) | 운영 중 |

## 4. 핵심 결정 대장 (ADR 요약)

| ID | 결정 | 근거 문서 |
|---|---|---|
| ADR-007 | 통합 로드맵 채택 (03.5/03.7/05.5/05.7 신설, Autoware는 05.7 후) | integrated_roadmap |
| ADR-008 | 평가 프레임워크는 별도 저장소 분리 | integrated_roadmap 7장 |
| (예정) ADR-009 | E안: 무인 경로 데이터 소스를 Runner 산출물+API polling으로 한정, rosbag은 유인 세션 | full_autonomy_analysis 3.3 |
| (예정) ADR-010 | rosbridge 소스 자격 판정 (hz 게이트 결과에 따라 진단 도구 격하 여부) | 진단 계획 6장 |

원장은 `records/decisions.tsv`가 유일 권위. 본 표는 요약 뷰이며 불일치 시 TSV가 이긴다.

## 5. 설계노트 정정 대기 목록 (Erratum Queue)

| 대상 | 내용 | 트리거 |
|---|---|---|
| 5.8 (ROS2 Native) | "공식 문서상 추가됨" → 실측 반증, AVS-007 참조·벤더 회신 대기 상태 표기 | Stage 05 실측 |
| Risk Register | R16(sourcedefender: 라이선스·Python 고정·재현성) — **실체 확인됨: 22.R3 lib 694개 `.pye`가 Python 3.7 고정, 3.7용 sourcedefender PyPI 소멸 (MORAI-002 §4)**; R17(ROS2 Native 실동작 불가 가능성), R18(ROS 연결의 세션별 GUI 강제) 등재 | AVS-006/007, 자율화 분석 |
| 9.4 (3원 소스) | '무인/유인' 컬럼 추가 (E안 채택 시) | ADR-009 |

## 6. 벤더 커뮤니케이션 현황 (요약 뷰 — 원장: records/vendor_comms.tsv)

(vendor_comms.tsv comm_id별 최신 행 기준, 2026-07-06)

| Comm ID (external_ref) | 대상 이슈 | 요지 | 상태 | 다음 액션 |
|---|---|---|---|---|
| MORAI-004 | AVS-006,007 | CTO(전형석 상무) 수신 커버 (001/002 첨부) | **SENT (2026-07-06)** | **1차 회신 대기 (~7/10)** |
| MORAI-001 (KATECH-SIM-ROS2) | AVS-007 | ROS2 Native ros2cs 예외 + rosbridge header.seq | **SENT** | MORAI-004 첨부로 발송 — 회신 대기 |
| MORAI-002 (KATECH-API-PY37) | AVS-006 | sourcedefender 보호 API 지원 Python·설치·라이선스 | **SENT** | MORAI-004 첨부로 발송 — 회신 대기 |
| MORAI-003 | R18 (기능요청) | ROS 연결 CLI/설정파일화·자동 Connect·런처 자동기동·Headless; sourcedefender 제거·공식 아카이브 | TODO_DRAFT | 초안 작성(001 회신 흐름에 병행) |

## 7. 다음 세션 착수 순서 (우선순위)

1. **MORAI 회신 추적 (1순위)** — MORAI-001/002/004 발송 완료(2026-07-06). due 2026-07-10까지 1차 회신·담당 연결 대기; 초과 시 리마인드(vendor_comms STALE→due 갱신). 회신 시 INBOX 저장 + ANSWERED 전이.
2. **SIM-불필요 트랙 착수** — GUI로 시나리오 1~2회 실행해 eventlog/statelog 실물 확보 → 스키마 인벤토리 → parser 골격+fixture.
3. (PC 접근 가능 시) **D1~D5 진단** — 사람 1분 세팅 후 원격 완주, AVS-007 귀속 확정.
4. **ADR-009(E안) 등재 + 설계노트 erratum 반영.**
5. **MORAI-003 초안 작성** — 001 회신 흐름에 병행.

**이번 세션(2026-07-04) 완료**: 문서체계 적용(vendor/·reports/·TSV·문서 이관), MORAI-001/002 초안, environment-morai-osc.yml 커밋(재현성 부채 청산).

## 8. 세션 인수인계 규약 (Session Handover Protocol)

**세션 시작 시**
1. PROJECT_STATUS.md 읽기 → 2. 직전 `reports/` 세션 리포트 1건 읽기 → 3. 착수 전 이번 세션 목표를 1~3줄로 선언

**세션 종료 시**
1. `reports/YYYY-MM-DD_session.md` 작성 (템플릿: 목표/완료/미완+이유/신규 이슈·결정/교훈/다음 세션 필수 작업)
2. PROJECT_STATUS.md 갱신: 2장 스냅샷, 6장 벤더 현황, 7장 우선순위
3. TSV 원장 반영 확인 (stages/issues/decisions/commands/vendor_comms)
4. 커밋·푸시

**불변 원칙**: TSV는 append-only + AMEND 규약. 정본 문서 정정은 erratum 명시 커밋. 추정 기입 금지 — 실측·사용자 확인만 기록.
