# T-24 — 벤더 진단("morai_msgs 미소싱") 검증 절차·기록

| 항목 | 내용 |
|---|---|
| 버전 | v2.0 (2026-07-10, **T-25 추가 — AVS-007 RESOLVED, 근본원인 H4 확정**) |
| 배경 | MORAI 회신(2026-07-08, 양종범): AVS-007은 "ROS2용 morai_msg가 빌드 환경에 소싱되지 않아 발생 — 환경 설정 확인 권장". 이 진단의 재검증. |
| 판정 | 맞으면 Stage 05 블로커 즉시 해소 / 틀리면 반증 증거로 재회신 |
| 스크립트 | `scripts/recheck/t24_observe.sh` (셀 N2·R2), 런처 `ROS2_OVERLAY` opt-in 추가 |

## 1. Step 0 — 기존 재현 조건 (실측 원장 기반, before 셀의 근거)

| 항목 | 기존 실측(E2/E3, 2026-07-06 N=3) |
|---|---|
| SIM | `Simulator_v.R1.260701.H3`, `scripts/run_morai_launcher_nvidia.sh` 기동 |
| Host ROS2 | Humble desktop(apt), rmw_fastrtps_cpp 6.2.10, fastrtps 2.6.11, RMW=fastrtps, LOCALHOST_ONLY=0 |
| Native | `SOURCE_ROS2=1` → Start → Player.log `std::bad_cast` + ss 74xx 폴링(D1) |
| rosbridge | rosbridge 9090 + SIM GUI Connect(Simulator/Ego/Sensor) → topics/echo(timeout) |

**사각지대·불일치 (Step 0.3 판정)**:
1. **Native "소싱 후" 셀은 미실측** — 런처 `SOURCE_ROS2=1`은 `/opt/ros/humble`만 소싱(오버레이 제외).
   Player.log의 `libmorai_ros2_msgs__*` preload는 SIM 번들 Plugins. SIM env의
   `ros2 interface list | grep -i morai` 기록 없음. → **실측 사각지대 확인**.
2. rosbridge는 msgs 소싱 상태였으나 **main 브랜치 빌드(b3db4e6, 2026-06-12)** — 태그 `26.R1`(2026-04-07)과
   84파일 차이(예: EgoVehicleStatus `front_steer_angle`→`front_steer`). 26.R1 정합 msgs 재시험은 신규 조건.
3. 공식 리포 패키지명 = `morai_ros2_msgs`(26.R1·HEAD 동일), msg **32종**(T-24 기재 33종과 1 차이).
   SIM rosbridge는 `morai_msgs/*` 타입 문자열 요구 → 리네임 사본 필요(2026-07-03 실측).

## 2. Step 1 — 확보·빌드·소싱 (2026-07-08 완료)

- 새 ws `~/avstack/ros2_ws_26r1` (기존 `~/avstack/ros2_ws`=main 빌드는 증거 보존, 불변).
- 클론 `MORAI-Autonomous/MORAI-ROS2_morai_msgs` → **태그 `26.R1`(c84d648) 체크아웃**.
- 2패키지 빌드: `morai_ros2_msgs`(공식명, native용) + `morai_msgs`(리네임, rosbridge용). colcon 16.9s 성공.
- 증거: `~/avstack/logs/avs007_t24_20260708_{env,iface}_{before,after}.txt`
  (before: morai 인터페이스 0건 / after: 76건 = 38×2), 빌드 로그 `~/avstack/runs/t24_morai_msgs_26r1_build_20260708.log`.
- 런처에 `ROS2_OVERLAY=<install경로>` opt-in 추가(기본 무동작, `SOURCE_ROS2=1`일 때만 유효).

## 3. Step 2 — 2×2 매트릭스 (소싱 전 = 기존 기록 갈음)

| 셀 | 조건 | 결과 | 근거 |
|---|---|---|---|
| N1: Native, 소싱 전(오버레이 없음) | SOURCE_ROS2=1 only | **FAIL** — startup std::bad_cast ×3, D1 participant 미생성 | E2(2026-07-06), vendor/morai/evidence/avs007_recheck_* |
| R1: rosbridge, main-msgs | rosbridge 9090 + main 빌드 | **FAIL** — 토픽 생성/echo 0, header.seq 거부 28,976건 | E3(2026-07-06), avs007b_recheck_* |
| **N2: Native, 26.R1 오버레이 소싱** | SOURCE_ROS2=1 + ROS2_OVERLAY | **FAIL (2026-07-10)** — 소싱 실물 증거(launcher environ에 ros2_ws_26r1 확인) 상태에서 startup std::bad_cast **동일 재현**(Player.log:547), D1 74xx 미바인딩. 기존과 동일하므로 r1 종결 | avs007_t24_20260710_N2r1_* (environ/player.log/ss) |
| **R2: rosbridge, 26.R1 msgs** | AVSTACK_WS=ros2_ws_26r1 | **FAIL (2026-07-10)** — 연결 client 33·토픽 23 생성되나 echo 0건/15s, header.seq 거부 observe 시점(11:41) 53,686건 → **15분 관찰창 누계 138,841건**(9타입, 표준 tf2_msgs/TFMessage 포함; 동결 샘플 분포 기준). CtrlCmd 역방향 53건 발행에도 차량 무반응(SIM 상태 전제 미확정) | avs007_t24_20260710_R2r1_* (rosbridge.log/topics/echo/ctrlpub) |

### GUI 세션 실행 순서 (사용자 인터리브, 회당 ~10분)

**N2 (SIM 크래시 여부 — 먼저, 회차마다 SIM 재기동):**
```
터미널A: SOURCE_ROS2=1 ROS2_OVERLAY=$HOME/avstack/ros2_ws_26r1/install \
         ~/avstack-control/scripts/run_morai_launcher_nvidia.sh
터미널B: ~/avstack-control/scripts/recheck/t24_observe.sh N2r1 start   # 런처 environ 캡처(소싱 증거)
[사용자] 런처: 지도 로드(K-City 등 4GB VRAM 내) → Start
터미널B: ~/avstack-control/scripts/recheck/t24_observe.sh N2r1 finish  # 시그니처·D1·(생존 시)토픽 자동
```
- SIM 생존 시 finish 가 topic list/echo 까지 자동 수행. 크래시 시 기존과 동일성 판정.
- 재현성 원칙상 r1 결과가 기존과 다르면(생존) r2·r3 반복.

**R2 (데이터 수신 여부 — SIM 일반 기동, ROS2 미소싱):**
```
터미널A: ~/avstack-control/scripts/run_morai_launcher_nvidia.sh   # 일반 기동
터미널B: t24_observe.sh R2r1 start
[사용자] SIM Network Settings: Simulator/Ego/Sensor → ROS 127.0.0.1:9090 Connect
터미널B: t24_observe.sh R2r1 observe        # echo 15s·hz·seq 거부 카운트
터미널B: (수신>0일 때만) t24_observe.sh R2r1 ctrl   # CtrlCmd 5s — [사용자] 차량 가속 육안 확인
터미널B: t24_observe.sh R2r1 cleanup
```

## 4. Step 3 — 분기 판정 기준

| 분기 | 조건 | 조치 |
|---|---|---|
| A | N2·R2 모두 해소 | 진단 옳음 — 환경 설정 절차 runbook 표준화, AVS-007 RESOLVED, Stage 05 재시험 |
| B | R2만 해소(N2 잔존) | 부분 — N2 크래시 로그+launcher_environ(소싱 증거)을 재회신 패키지로; Stage 05는 rosbridge로 진행 검토 |
| C | 둘 다 잔존 | 진단 틀림 — "소싱 완료 상태에서 동일 증상" 증거 패키지(environ 캡처 포함)로 재회신 |

**사전 예측 (사실/추론 분리)**: (추론) R2의 header.seq 거부는 `std_msgs/Header`(ROS2 코어, seq 없음)에
기인하므로 어떤 morai_msgs 버전으로도 해소 불가 예상 → 분기 B 또는 C 가능성 높음. N2는 미검증 셀이므로
예단하지 않음(bad_cast가 rcl 초기화 계층이라는 관측은 있으나, 소싱-후 동작은 실측 전 미지).
**예측과 다르면 예측이 아니라 기록을 갱신한다.**

### 판정 (2026-07-10): **분기 C — 벤더 진단 틀림**

- (사실) N2: 오버레이 소싱이 SIM 부모 프로세스 env에 반영된 실물 증거(`_launcher_environ.txt`,
  `AMENT_PREFIX_PATH=…ros2_ws_26r1…`) 상태에서 기존과 자리까지 동일한 `std::bad_cast`(rcl 초기화, functions.cpp:65) 크래시.
- (사실) R2: 26.R1 정합 msgs 소싱·타입 해석 정상(iface_ego.txt)에도 SIM publish 전량 거부 — 거부 9타입 전부
  `header.seq`이고 **표준 tf2_msgs 포함**(morai_msgs와 무관함을 그 자체로 증명). 역방향 CtrlCmd도 무반응.
- (추론) 원인은 우리 환경의 msgs 소싱이 아니라 SIM 측: native=rmw 로드 계층 실패(H2 RTTI/H3),
  rosbridge=SIM이 ROS1 포맷(header.seq)으로 발행. → 재회신 필요(증거 패키지 동봉).
- GUI 절차 정정(실측): 런처 → **Start 먼저** → 이후 지도·차량 선택. §3의 "지도 로드 → Start" 표기는 구버전 순서.
  또한 SIM Network(Simulator/Ego/Sensor)는 이번 실측에서 **자동 연결**돼 있었음(수동 Connect 불요).

## 6. T-25 — 벤더 2차 회신(2026-07-10) 재확인 요청의 검증과 근본원인 확정

벤더 2차 회신: 자기 환경 정보(Ubuntu 22.04.5, fastdds 2.6.10/rmw 6.2.8 2025-07 sync, morai_msgs main 클론) +
**"소싱 후 런처 바이너리 직접 실행" 재확인 요청** + rosbridge는 ROS2 경로 아님(공식) + API py3.13 재빌드 납품.

| 셀 | 조건 | 결과 | 근거 |
|---|---|---|---|
| **N3: 벤더 방식** | humble+ros2_ws(main) 소싱, RMW 미설정, 바이너리 직접 | **동작** — SIM 생존(시그니처 無), ROS2 Connect 후 participant 생성·토픽 18종(`morai_ros2_msgs` 타입)·/ego_vehicle_status **50.2Hz**·CtrlCmd 제어 | avs007_t24_20260710_N3r1_* |
| **T-25 3국면**(N3r2) | A drift / B freeze / C cmd | A: 무명령 크리프=중력 롤링(0.4→0.6m/s 가속). B: **설정창 열림=물리 일시정지**(10s 위치 완전 동결, 토픽은 마지막 값 반복). C: velocity 10km/h 명령→1.5s 내 2.778m/s 추종, stop→1s 내 0·위치 고정, 반복 재현 — **역방향 제어 확정** | avs007_t25_20260710_N3r2_track.log |
| **N4: H4 확정** | N3 + `RMW_IMPLEMENTATION=rmw_fastrtps_cpp`만 추가 | **크래시** — Player.log:547 동일 std::bad_cast | avs007_t24_20260710_N4r1_* |

**재판정 (v2.0 확정)**:
- (사실) 크래시 트리거 = **`RMW_IMPLEMENTATION` 환경변수**. 설정 시 rcl `rmw_implementation_identifier_check`
  경로가 열리고 그 dlopen에서 std::bad_cast(N4). 미설정 시 검사 생략 → 정상(N3). 우리 래퍼가 이 변수를
  항상 설정했던 것이 N1·N2 크래시의 원인 — **소싱 여부·msgs 버전·host 패치버전과 전부 무관**
  (T-24 분기 C "벤더 진단(미소싱) 틀림" 판정은 유지되나, 벤더의 재확인 요청이 결과적으로 원인 규명을 이끎).
- (사실) rosbridge 경로는 벤더 공식 비지원(ROS1 포맷 발행) → 폐기. native가 유일 공식 경로.
- **동작 레시피(Stage 05 표준)**: ① humble + morai msgs ws 소싱(오버레이), ② RMW_IMPLEMENTATION **미설정/해제**,
  ③ 런처 기동(직접/래퍼 무관 — 래퍼 SOURCE_ROS2=1 이 이 레시피로 정정됨), ④ SIM: Start→지도/차량→**ROS2 Connect**,
  ⑤ **설정창 모두 닫기**(열려 있으면 물리 일시정지), ⑥ 제어는 MultiEgoSetting ctrl_mode=16(auto)+gear=4 후 CtrlCmd.
- 결과: **AVS-007 RESOLVED, Stage 05 PASS** (records/stages.tsv 2026-07-10).

## 7. 산출물 체크리스트 (실행 세션에서)
- [x] records/commands.tsv append (N2·R2 각 회차) — 2026-07-10 2행
- [x] records/issues.tsv AVS-007 AMEND (매트릭스 결과 반영) — 2026-07-10
- [x] 본 문서 §3 표 갱신 + 분기 판정 기입 — §4 분기 C
- [ ] [MGMT] 반영 체크리스트: SIM-05 판정 / TECH-03·TECH-14·TECH-25 status 변경안 / 벤더 재회신 여부·요지 / kb/morai/observed 요약 1건
- [x] 재회신 필요 시: vendor/morai/OUTBOX 에 MORAI-001 후속 초안(evidence 동결 규약 준수) — MORAI-001_avs007_t24_followup.md
