# 저장소 경계 정의 (Repository Boundaries)

| 항목 | 내용 |
|---|---|
| 버전 | v1.0 |
| 작성일 | 2026-07-06 |
| 위치 | `~/avstack-control/runbooks/repo_boundaries.md` |
| 성격 | **내구성 규칙** — 4개 저장소 계층의 역할·경계를 확정 |
| 관련 | ADR-011(경계 결정), AVS-008(STATUS.md 판정 불일치) |

---

## 1. 핵심 원칙

> **"정의는 git, 재생성물은 밖."**
> 사람이 작성·결정한 정의/기록은 git 저장소에 둔다. 실행으로 다시 만들어낼 수 있는 것(바이너리,
> 로그, 런 산출물)은 git 밖(non-git)에 둔다.

## 2. 4층 경계

| 계층 | 저장소 | 성격 | 담는 것 | 담지 않는 것 |
|---|---|---|---|---|
| ① 정의 | **oss3-scenarios** (git) | 입력 정의 | 시나리오(.xosc), MGeo/맵 매니페스트, 시나리오 파라미터 | 실행 로그, 판정 |
| ② 실행 | **~/avstack** (**non-git**) | 재생성물(런타임) | SIM/Runner 바이너리, eventlog/statelog, rosbag, 런 산출물, 캐시 | 정의(→①), 판정 원장(→③) |
| ③ 판정·정본 | **avstack-control** (git, 본 저장소) | 사실 원장 + 절차/설계 + 도구 정본 | records/*.tsv(판정), runbooks(절차·설계), scripts·env·VERSIONS(도구 정본), vendor(대외소통) | 시나리오 정의(→①), 재생성 산출물(→②) |
| ④ 요약·계획 | **mgmt** (git) | 상위 뷰 | 과제 계획(plans/WP), 진행 요약, 대외 보고 | 실측 원장(→③가 권위) |

> ①·④(oss3-scenarios, mgmt)는 목표 외부 저장소다. 로컬 부재 시에도 본 경계가 편입 기준이 된다.

## 3. 데이터 흐름

```
oss3-scenarios(정의)  →  ~/avstack(실행)  →  avstack-control/records(판정)  →  mgmt(요약)
   .xosc/MGeo            SIM/Runner 실행        stages/issues/... TSV            plans/WP 진행 뷰
```

- 상류(정의)→하류(요약) 단방향. 하류는 상류를 **참조**하되 **복제·수정하지 않는다**.
- 충돌 시 우선순위: **records/*.tsv(③) = 판정의 유일 권위**. 요약(④)·문서는 뷰이며 원장이 이긴다.

## 4. 편입/배치 판정 (새 산출물을 어디에 둘지)

| 질문 | → 계층 |
|---|---|
| 시나리오·맵 정의인가? | ① oss3-scenarios |
| 실행하면 다시 생기는가(로그/바이너리/런)? | ② ~/avstack (non-git) |
| 판정·결정·절차·도구 정본인가? | ③ avstack-control |
| 과제 계획·상위 요약인가? | ④ mgmt |

## 5. 현재 정합 과제 (참조)
- **AVS-008**: `~/avstack/STATUS.md`(Stage 0~8 판정)와 `records/stages.tsv`(00~04 PASS/05 FAIL) 이중 판정 →
  STATUS.md 를 stages.tsv **포인터**로 전환하고 스테이지 체계를 **00~04 계열로 일원화**. 판정 권위는 stages.tsv 단일.
- **ADR-011**: `~/avstack` 비-git 유지, scenarios·맵 매니페스트는 oss3-scenarios로 추출, VERSIONS·scripts·env 정본은 avstack-control.
