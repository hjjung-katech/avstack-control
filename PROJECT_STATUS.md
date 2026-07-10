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
| 05 | MORAI ROS2 Native Topic | **PASS (2026-07-10)** | AVS-007 RESOLVED — 원인=RMW_IMPLEMENTATION 변수(H4). 수신 50.2Hz+제어 실측 |
| 05.5 / 05.7 | Batch 파이프라인 / 캘리브레이션 | 대기 | 03.7 게이트 종속 |
| 06~08 | Autoware | 보류 | 05.7 통과 후 (ADR-007) |

### 크리티컬 패스 진단

**ROS2 Native 경로 개통(2026-07-10, Stage 05 PASS).** 남은 벤더 의존은 AVS-006(API py3.13 재빌드 — 수령됨, 검증 대기)뿐. 진행 트랙:

1. **AVS-006 검증 트랙**: py3.13 env 구성 → 재빌드 API import/계약 검증 → Stage 03.5→03.7 게이트.
2. **ROS2 활용 트랙**: Stage 05 개통으로 E안(무인 데이터 경로) 재평가 여지 — ROS2 native 수신이 가능해졌으므로 ADR-009의 "L6에서 ROS2 Native 제외" 전제 재검토 후보.
3. **SIM-불필요 트랙**: parser/metric/verdict 골격 + golden fixture([EVAL] 리포 결정 전제).
4. **벤더 트랙**: MORAI-001 3차 회신(해결 보고) 초안 검토·발송. MORAI-003(기능요청) 초안 대기.

### 열린 이슈 (요지)

| ID | 요지 | 상태 | 벤더 의존 |
|---|---|---|---|
| AVS-006 | Python API sourcedefender — **py3.13 재빌드 수령(2026-07-10)**, env 구성·검증 대기 | 검증 대기 | O |
| AVS-007 | ~~ROS2 연동 차단~~ **RESOLVED(2026-07-10)** — 원인=RMW_IMPLEMENTATION 변수, native 수신+제어 실측 | RESOLVED | 해소 |

## 3. 문서 지도 (Document Map)

| 문서 | 위치 | 역할 | 상태 |
|---|---|---|---|
| **PROJECT_STATUS.md** | 루트 | 마스터 인덱스 (본 문서) | 살아있음 |
| 설계노트 v1.1 | `runbooks/framework_design_note_v1.1.md` | 프레임워크 설계 기준 (Phase/V-검증/21·22장) | v1.1 (5.8/9.4 erratum 반영) |
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
| ADR-009 | E안: 무인 경로 데이터 소스 = Runner 산출물+API polling, rosbag=유인 세션, L6에서 ROS2 Native 제외 | full_autonomy_analysis 3.3 |
| (예정) ADR-010 | rosbridge 소스 자격 판정 (hz 게이트 결과에 따라 진단 도구 격하 여부) | 진단 계획 6장 |

원장은 `records/decisions.tsv`가 유일 권위. 본 표는 요약 뷰이며 불일치 시 TSV가 이긴다.

## 5. 설계노트 정정 대기 목록 (Erratum Queue)

| 대상 | 내용 | 트리거 |
|---|---|---|
| ~~5.8 (ROS2 Native)~~ **해소(2026-07-06)** | 실측 반증 erratum 반영(AVS-007, D1=FAIL) | Stage 05 실측 |
| Risk Register | R16(sourcedefender: 라이선스·Python 고정·재현성) — **실체 확인됨: 22.R3 lib 694개 `.pye`가 Python 3.7 고정, 3.7용 sourcedefender PyPI 소멸 (MORAI-002 §4)**; R17(ROS2 Native 실동작 불가 가능성), R18(ROS 연결의 세션별 GUI 강제) 등재 | AVS-006/007, 자율화 분석 |
| ~~9.4 (3원 소스)~~ **해소(2026-07-06)** | 무인/유인 구분 erratum 반영 | ADR-009 |

## 6. 벤더 커뮤니케이션 현황 (요약 뷰 — 원장: records/vendor_comms.tsv)

(vendor_comms.tsv comm_id별 최신 행 기준, 2026-07-10)

| Comm ID (external_ref) | 대상 이슈 | 요지 | 상태 | 다음 액션 |
|---|---|---|---|---|
| MORAI-004 | AVS-006,007 | CTO 커버 → 기술담당(양종범) 1차 회신 수신(2026-07-08) | **ANSWERED** | 후속은 001/002 개별 트랙 |
| MORAI-001 (KATECH-SIM-ROS2) | AVS-007 | 재회신→2차 회신(직접 실행 재확인 요청)→**T-25로 원인 확정(RMW 변수)·해결** | **3차 회신 DRAFT** | 해결 보고 초안 검토·발송 (OUTBOX/MORAI-001_t25_resolution_email.md) |
| MORAI-002 (KATECH-API-PY37) | AVS-006 | Python 업그레이드 후 API 재빌드 제공 예정(목표 2026-07-10) | **ANSWERED** | 재빌드 수령 대기 — 수령 시 env 재생성 + Stage 03.5 재개 |
| MORAI-003 | R18 (기능요청) | ROS 연결 CLI/설정파일화·자동 Connect·런처 자동기동·Headless; sourcedefender 제거·공식 아카이브 | TODO_DRAFT | 초안 작성(001 재회신 흐름에 병행) |

## 7. 다음 세션 착수 순서 (우선순위)

1. **AVS-006 검증 (1순위)** — py3.13 재빌드 API 수령 완료(.eml 전송 대기). 첨부 추출 → py3.13 conda env(yml 커밋) → import/계약 검증 → **Stage 03.5 재개**.
2. **MORAI-001 3차 회신(해결 보고) 발송** — 초안 검토 → 발송 → SENT 동결·전이.
3. **ADR-009 재검토** — Stage 05 개통으로 "L6에서 ROS2 Native 제외" 전제 변경 여부 결정(ADR 갱신 or 유지).
4. **SIM-불필요 트랙 / MORAI-003 초안** — 병행.

**이번 세션(2026-07-10) 완료**: ① T-24 매트릭스(N2·R2 FAIL, 분기 C)+재회신 발송, ② 벤더 2차 회신 수신 → **T-25: 벤더 방식 정상 동작, H4 확정(RMW_IMPLEMENTATION=크래시 트리거), 역방향 제어 실측(3국면 판별), 설정창=물리 일시정지 규명** → **AVS-007 RESOLVED, Stage 05 PASS**, 래퍼 정정, 3차 회신 초안. API py3.13 납품 수령.

## 8. 세션 인수인계 규약 (Session Handover Protocol)

**세션 시작 시**
1. PROJECT_STATUS.md 읽기 → 2. 직전 `reports/` 세션 리포트 1건 읽기 → 3. 착수 전 이번 세션 목표를 1~3줄로 선언

**세션 종료 시**
1. `reports/YYYY-MM-DD_session.md` 작성 (템플릿: 목표/완료/미완+이유/신규 이슈·결정/교훈/다음 세션 필수 작업)
2. PROJECT_STATUS.md 갱신: 2장 스냅샷, 6장 벤더 현황, 7장 우선순위
3. TSV 원장 반영 확인 (stages/issues/decisions/commands/vendor_comms)
4. 커밋·푸시

**불변 원칙**: TSV는 append-only + AMEND 규약. 정본 문서 정정은 erratum 명시 커밋. 추정 기입 금지 — 실측·사용자 확인만 기록.
