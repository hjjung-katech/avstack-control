# 저장소 경계 정의 (Repository Boundaries)

| 항목 | 내용 |
|---|---|
| 버전 | v1.1 |
| 작성일 | 2026-07-06 |
| 위치 | `~/avstack-control/runbooks/repo_boundaries.md` |
| 성격 | **내구성 규칙** — 5개 저장소의 역할·경계·별칭을 확정 |
| 관련 | ADR-011(경계 결정 + 명명 확정), ADR-008([EVAL] 분리), AVS-008(STATUS.md 판정 불일치) |

**Change Log**
- v1.1 (2026-07-06): 4층 → **5리포 별칭 체계** 확정. [MGMT]=oss3-mgmt(최종명), [EVAL]=avstack-eval 예약.

---

## 1. 핵심 원칙

> **"정의는 git, 재생성물은 밖."**
> 사람이 작성·결정한 정의/기록은 git 저장소에 둔다. 실행으로 다시 만들어낼 수 있는 것(바이너리,
> 로그, 런 산출물)은 git 밖(non-git)에 둔다.

## 2. 5리포 체계 + 별칭

**별칭 표** (이하 본문은 별칭 사용):

| 별칭 | 저장소명 | git | 역할 |
|---|---|---|---|
| **[SCEN]** | `oss3-scenarios` (예정) | git | 시나리오·맵 정의(입력) |
| **[WS]** | `~/avstack` | **non-git** | 실행 런타임·재생성물 |
| **[CONTROL]** | `avstack-control` (본 리포) | git | 판정 원장·절차/설계·도구 정본·대외소통 |
| **[EVAL]** | `avstack-eval` (예정) | git | 평가 프레임워크 코드(parser/metric/verdict) — ADR-008 |
| **[MGMT]** | `oss3-mgmt` | git | 과제 계획(plans/WP)·상위 요약 |

**역할·경계**:

| 별칭 | 성격 | 담는 것 | 담지 않는 것 |
|---|---|---|---|
| [SCEN] | 입력 정의 | 시나리오(.xosc), MGeo/맵 매니페스트, 파라미터 | 실행 로그, 판정 |
| [WS] | 재생성물(런타임) | SIM/Runner 바이너리, eventlog/statelog, rosbag, 런 산출물, 캐시 | 정의(→[SCEN]), 판정 원장(→[CONTROL]) |
| [CONTROL] | 사실 원장 + 절차/설계 + 도구 정본 | records/*.tsv(판정), runbooks, scripts·env·VERSIONS(정본), vendor(대외소통) | 시나리오 정의(→[SCEN]), 재생성 산출물(→[WS]), 프레임워크 코드(→[EVAL]) |
| [EVAL] | 평가 프레임워크 코드 | parser/metric/verdict 구현, 테스트·fixture | 판정 원장(→[CONTROL]), 런 산출물(→[WS]) |
| [MGMT] | 상위 뷰 | 과제 계획(plans/WP), 진행 요약, 대외 보고 | 실측 원장(→[CONTROL]가 권위) |

> [SCEN]·[EVAL]·[MGMT]는 목표 외부 저장소다(일부 예정). 로컬 부재 시에도 본 경계가 편입 기준이 된다.

## 3. 데이터 흐름

```
[SCEN] 정의  →  [WS] 실행  →  [EVAL] 평가(코드)  →  [CONTROL]/records 판정  →  [MGMT] 요약
 .xosc/MGeo     SIM/Runner     parser/metric/verdict      stages/issues/... TSV       plans/WP 진행 뷰
```

- 상류(정의)→하류(요약) 단방향. 하류는 상류를 **참조**하되 **복제·수정하지 않는다**.
- 충돌 시 우선순위: **[CONTROL]/records/*.tsv = 판정의 유일 권위**. 요약([MGMT])·문서는 뷰이며 원장이 이긴다.

## 4. 편입/배치 판정 (새 산출물을 어디에 둘지)

| 질문 | → 리포 |
|---|---|
| 시나리오·맵 정의인가? | [SCEN] |
| 실행하면 다시 생기는가(로그/바이너리/런)? | [WS] (non-git) |
| 판정·결정·절차·도구 정본인가? | [CONTROL] |
| 평가 프레임워크 코드(parser/metric/verdict)인가? | [EVAL] |
| 과제 계획·상위 요약인가? | [MGMT] |

## 5. 현재 정합 과제 (참조)
- **AVS-008**: `[WS]/STATUS.md`(Stage 0~8 판정)와 `[CONTROL]/records/stages.tsv`(00~04 PASS/05 FAIL) 이중 판정 →
  STATUS.md 를 stages.tsv **포인터**로 전환하고 스테이지 체계를 **00~04 계열로 일원화**. 판정 권위는 stages.tsv 단일.
- **ADR-011**: [WS] 비-git 유지, scenarios·맵 매니페스트는 [SCEN]으로 추출, VERSIONS·scripts·env 정본은 [CONTROL].
  관리 리포 최종명 **oss3-mgmt([MGMT])**, 프레임워크 리포명 **avstack-eval([EVAL])** 예약(ADR-008 연계).
