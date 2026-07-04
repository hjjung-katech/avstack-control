# PROJECT_STATUS — AVStack 자동화 평가 프레임워크

| 항목 | 내용 |
|---|---|
| 문서 성격 | **살아있는 마스터 인덱스** — 모든 세션의 시작점이자 종료점 |
| 위치 | `~/avstack-control/PROJECT_STATUS.md` (저장소 루트) |
| 스냅샷 기준일 | 2026-07-04 |
| 갱신 규약 | 매 세션 종료 시 갱신 (12장 인수인계 규약 참조) |

> **이 문서의 사용법**: 새 세션(사람 또는 Claude Code)은 이 문서를 가장 먼저 읽는다.
> 여기서 현재 상태·열린 스레드·다음 액션을 파악한 뒤, 필요한 상세는 3장 문서 지도를 따라간다.

---

## 1. 프로젝트 한 줄 정의

MORAI SIM 26.R1 + Scenario Runner를 실행 엔진으로 하는 **재현 가능한 시나리오 자동 평가 프레임워크** 구축. Built-in 기준선 우선, Autoware는 이후 확장 (설계노트 Decision 1).

## 2. 현재 상태 스냅샷 (2026-07-04)

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
4. **벤더 트랙**: MORAI 문의 발송·추적 (vendor/ 체계)

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
| AVS-007 진단 계획 | `runbooks/avs-007_layer_diagnosis.md` | D1~D5 실험 카드 + 판정 매트릭스 | 실행 대기 |
| 완전 자율화 분석 | `runbooks/full_autonomy_analysis.md` | GUI 자동화 vs 아키텍처 우회(E안) | PoC 대기 |
| MORAI 문의 초안 | `vendor/morai/OUTBOX/` (이관 예정) | AVS-007 문의 패키지 | **발송 대기 (사용자 액션)** |
| 세션 회고 | `reports/` (이관 예정) | 세션별 완료·교훈 기록 | 규약 신설 |
| records/*.tsv | `records/` | 불변 원장 (stages/issues/decisions/commands + vendor_comms 신설) | 운영 중 |

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
| Risk Register | R16(sourcedefender: 라이선스·Python 고정·재현성), R17(ROS2 Native 실동작 불가 가능성), R18(ROS 연결의 세션별 GUI 강제) 등재 | AVS-006/007, 자율화 분석 |
| 9.4 (3원 소스) | '무인/유인' 컬럼 추가 (E안 채택 시) | ADR-009 |

## 6. 벤더 커뮤니케이션 현황 (요약 뷰 — 원장: records/vendor_comms.tsv)

| Comm ID | 대상 이슈 | 요지 | 상태 | 다음 액션 |
|---|---|---|---|---|
| MORAI-001 | AVS-007 | ROS2 Native ros2cs 예외 + rosbridge header.seq 실측 보고·질의 | **DRAFT→발송 대기** | 사용자 발송, D1 실측 확보 시 증거 보강 |
| MORAI-002 | AVS-006 | sourcedefender 보호 API의 지원 Python 버전·설치 절차·라이선스 조건 질의 | 초안 필요 | 초안 작성 |
| MORAI-003 | (기능 요청) | CLI/설정파일 기반 ROS 연결, 시나리오 시작 시 자동 Connect, 런처 자동기동 인자, Headless 로드맵 | 초안 필요 | MORAI-001 회신 흐름에 병행 |

## 7. 다음 세션 착수 순서 (우선순위)

1. **MORAI-001 발송** — 유일한 사용자 액션, 최고 레버리지. 발송 즉시 vendor_comms.tsv에 SENT 기록.
2. **문서체계 적용** — `문서체계_및_벤더관리.md`의 Claude Code 프롬프트 실행 (vendor/·reports/ 신설, TSV 추가, 문서 이관).
3. **SIM-불필요 트랙 착수** — GUI로 시나리오 1~2회 실행해 eventlog/statelog 실물 확보 → 스키마 인벤토리 → parser 골격+fixture.
4. (PC 접근 가능 시) **D1~D5 진단** — 사람 1분 세팅 후 원격 완주, AVS-007 귀속 확정.
5. **ADR-009(E안) 등재 + 설계노트 erratum 반영.**
6. environment.yml(Conda) 커밋 — sourcedefender 재현성 부채 청산.

## 8. 세션 인수인계 규약 (Session Handover Protocol)

**세션 시작 시**
1. PROJECT_STATUS.md 읽기 → 2. 직전 `reports/` 세션 리포트 1건 읽기 → 3. 착수 전 이번 세션 목표를 1~3줄로 선언

**세션 종료 시**
1. `reports/YYYY-MM-DD_session.md` 작성 (템플릿: 목표/완료/미완+이유/신규 이슈·결정/교훈/다음 세션 필수 작업)
2. PROJECT_STATUS.md 갱신: 2장 스냅샷, 6장 벤더 현황, 7장 우선순위
3. TSV 원장 반영 확인 (stages/issues/decisions/commands/vendor_comms)
4. 커밋·푸시

**불변 원칙**: TSV는 append-only + AMEND 규약. 정본 문서 정정은 erratum 명시 커밋. 추정 기입 금지 — 실측·사용자 확인만 기록.
