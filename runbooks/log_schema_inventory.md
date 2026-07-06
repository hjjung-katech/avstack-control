# 로그 스키마 인벤토리 (Scenario Runner eventlog/statelog/result)

| 항목 | 내용 |
|---|---|
| 버전 | v1.0 |
| 작성일 | 2026-07-06 |
| 위치 | `~/avstack-control/runbooks/log_schema_inventory.md` |
| 목적 | 설계노트 **V7.5(로그 스키마 인벤토리)** — 공식 미명세 컬럼 스키마를 **실측으로 확정**. parser/metric/verdict의 정본. |
| 성격 | 분석·정본([CONTROL] 소관). 파서 **코드**는 [EVAL] avstack-eval 소관(리포 생성 시점). |

**출처 데이터** (Stage 03 Built-in 실행, 재실행 불필요):
`~/avstack/.../logs_scenario_runner/simulation_20260702_*` — 시나리오 `Scenario_Cut_In_1`, 맵 `R_KR_PG_KATRI`.
정상 3회(181441/182045/182148: statelog ~1000행/event 31행/result 5행) + 빈 1회(175541).

---

## 1. result.csv — 판정(verdict) 계층

**스키마** (2블록):
```
No.,File Name,Map Name,Duration (sec),SUCCESS/FAILURE      # 시나리오별 1행
Total,Success,Failure,None                                # 요약 1행
```
예: `1,Scenario_Cut_In_1,R_KR_PG_KATRI,10.02,NONE` / `1,0,0,1`

- 판정 도메인: **SUCCESS / FAILURE / NONE**. **실측 3회 모두 `NONE`** — Built-in 실행이 pass/fail 평가 기준을
  트리거하지 않아 미판정(NONE). → verdict 로직은 result의 판정값 + (필요 시) statelog 지표 임계 조합으로 구성.
- 파일명에 시나리오·맵 포함 → 추적성 확보.

## 2. eventlog — 이벤트 타임라인 / 경계 감지 계층

**스키마** (3컬럼): `time (sec),Log_Level,Description`
- Log_Level: `Info` 등. Description: 자유 텍스트(OpenSCENARIO 스토리보드 요소 상태).

**이벤트 어휘**(31행 실측) 및 **경계 감지 매핑**(Stage 03.7):
| 이벤트(Description) | 의미 | 경계 신호 |
|---|---|---|
| `Storyboard is started` | 시나리오 시작 | **시작 경계** |
| `Storyboard is stopped` / `Test End` | 시나리오 종료 | **종료 경계** |
| `Story/Act/ManeuverGroup/Maneuver/Event/LateralAction ... started/stopped` | 계층별 상태 전이 | 세부 구간 |
| `EnvironmentAction is started/ended` | 초기화(Init) | 프리롤 |
| `SimulationTimeCondition/DistanceCondition is triggered` | 트리거 발동 | 조건 충족점 |
| `Scenario Evaluation Indices` | 평가지표 섹션 마커 | — |

→ **경계 감지 1차 신호 = `Storyboard is started` ~ `Storyboard is stopped`/`Test End`** (get_stop_status 폴링의 로그측 대응).

## 3. statelog — 상태 시계열 / **Metric 정본 계층**

**스키마** (22컬럼, per-entity·per-timestep): 엔티티 = `Ego, NPC_1, NPC_2` (다중). Duration ~10.02s.
```
time (sec), Entity, PositionX/Y/Z (m),
VelocityX/Y/Z(EntityCoord) (km/h), AccelerationX/Y/Z(EntityCoord) (m/s2),
RotationX/Y/Z (deg), Throttle [0..1], Brake [0..1], FrontWheelAngle (deg),
Exceeding Speed (km/h), Deficit Speed (km/h), TimeToCollision (sec), VtV Distance (m), WayOff Distance (m)
```

**설계노트 지표(Decision 5) → statelog 컬럼 매핑 — 6개 지표 전부 존재**:
| 설계노트 지표 | statelog 컬럼 | 단위 |
|---|---|---|
| Safe Distance | `VtV Distance` (Vehicle-to-Vehicle) | m |
| Time To Collision (TTC) | `TimeToCollision` | sec |
| Way-off Distance | `WayOff Distance` | m |
| Longitudinal Acceleration | `AccelerationX(EntityCoord)` | m/s² |
| Lateral Acceleration | `AccelerationY(EntityCoord)` | m/s² |
| Speed Excess | `Exceeding Speed` | km/h |
| Speed Deficit | `Deficit Speed` | km/h |

→ **Metric 정본 = statelog** (엔티티별 시계열). 파서는 (time, Entity) 키로 지표 컬럼을 추출·집계(min TTC, max WayOff 등).

## 4. 빈 로그 관찰 (재현성 참고)
- `simulation_20260702_175541`: eventlog/statelog **0바이트(빈)**, result만 존재(4행, 판정 없음).
- 정상 3회는 event 31·state ~1000행. → **빈 로그 = 실패/미완 실행의 시그니처**. 파이프라인은 statelog 0바이트를
  "무효 실행"으로 걸러야 함(파서 사전 검증 규칙).

## 5. 파서·fixture 시사 ([EVAL] 착수용)
- **3-계층 파서**: result(판정) / eventlog(경계·이벤트) / statelog(지표 시계열). 공통 키: 시나리오·맵·수행시각(파일명).
- **golden fixture 후보**: `simulation_20260702_181441`(정상, statelog 1210행) + `175541`(빈-무효 케이스). [EVAL] 생성 시
  이 2개를 fixture로 복사해 파서 단위·회귀 테스트 골든으로 사용.
- **사전 검증 규칙**: statelog 0바이트/헤더-only → 무효 실행. verdict NONE → 평가기준 미트리거(정상일 수 있음).
- 스키마는 이 문서가 정본(V7.5). 컬럼 변경 관측 시 erratum.
