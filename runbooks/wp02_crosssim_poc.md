# WP-02 크로스시뮬레이터 PoC — 실행 절차 (자리 확보)

| 항목 | 내용 |
|---|---|
| 버전 | v0.1 (scaffold) |
| 작성일 | 2026-07-06 |
| 위치 | `~/avstack-control/runbooks/wp02_crosssim_poc.md` |
| 상태 | **자리 확보(scaffold)** — WP-02 수용 대비. 절차는 착수 시 채운다. |

---

## 0. 경계 (정본 소재)

- **매트릭스·수용기준 정의의 정본 = [MGMT](oss3-mgmt) plans/WP-02** (외부 저장소). 본 문서에서 매트릭스를
  재정의·복제하지 않는다.
- **본 문서([CONTROL])의 역할 = 실행 절차 + 실행 기록·증거 위치**. 판정은 `records/stages.tsv` 단일 권위.
  (경계: `runbooks/repo_boundaries.md`, ADR-011)

## 1. 목적
크로스시뮬레이터(예: MORAI ↔ 타 시뮬) 간 시나리오/토픽/판정 재현성을 PoC로 확인한다. *(상세 목표·매트릭스는 [MGMT] WP-02.)*

## 2. 선행 조건 *(착수 시 확정)*
- [ ] 대상 시뮬레이터/버전, 공통 시나리오 소스([SCEN] oss3-scenarios)
- [ ] 실행 환경([WS] ~/avstack) 준비

## 3. 실행 절차 *(TBD — 착수 시 작성)*
- 단계별 명령·스크립트는 `scripts/`에 두고, 여기에 절차만 기술.

## 4. 실행 기록·증거 위치
- 명령 기록: `records/commands.tsv`
- 원본 로그/런 산출물: `~/avstack/runs`, `~/avstack/logs` (non-git, [WS]) — TSV에는 경로만.
- 증거 동결(대외 필요 시): `vendor/*/evidence/`.

## 5. 판정 반영
- PoC 결과의 스테이지 판정은 **`records/stages.tsv`** 에만 기록(`scripts/record_stage.sh`). STATUS 류 별도 판정 금지(AVS-008).
