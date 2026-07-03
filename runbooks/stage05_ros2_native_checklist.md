# Stage 05 — MORAI ROS2 Native Topic 체크리스트 (26.R1)

작업 정의: `runbooks/integrated_roadmap.md` 3장 표(Stage 05) — **"topic 확인 + sim/wall clock offset 측정"** (V7 준비).
선행: Stage 04 PASS(완료). 게이트 아님.

## ⛔ 현재 블로커 — AVS-007 (ROS2 Native ABI 불일치, 2026-07-03)

SIM ros2cs 는 **Humble 2023-03-31 빌드(standalone=0)**, host Humble 은 **2026-06 패치** →
fastrtps/typesupport ABI 불일치. 결과:
- ROS2 소싱(SOURCE_ROS2=1): SIM startup 에서 `librmw_fastrtps_cpp.so std::bad_cast` → SIM 종료.
- 미소싱(기본): SIM 정상 시작하나 Connect 시 `librcl not found` → Disconnect 유지.
→ **현재 host Humble 로는 native 불가.** 증거: `~/avstack/logs/avs007_ros2cs_abi_mismatch_20260703.md`.

**대응 후보**: ① rosbridge 경로 우회(ros2cs/DDS ABI 안 탐, 이 환경에서 연결 실적 있음),
② host ROS2 를 SIM 빌드시점(2023-03) 버전으로 정합, ③ MORAI 문의(정확한 Humble 패치/standalone 빌드).
아래 native 절차는 AVS-007 해결 후 유효.

---

## 0. 아키텍처 (26.R1 기준, 2026-07-03 재정렬)

MORAI SIM 26.R1 은 **ROS2 Humble 을 native 지원**한다(rosbridge / morai_ros2_connector 불필요).
연동은 두 채널로 분리한다:

```
Scenario Runner  ──(gRPC, 7789)──▶  MORAI SIM: Drive 26.R1  ──(ROS2 Native, CycloneDDS)──▶  ROS2 / Autoware / 사용자 알고리즘
  .xosc/MGeo 제어                     지도·차량·센서·물리                    센서·상태 수신 / Ego 제어 명령 송신
```

- **Scenario Runner ↔ SIM = gRPC(7789)** — 시나리오/엔티티 제어. (Stage 03.5/03.7 트랙)
- **사용자·Autoware ↔ SIM = ROS2 Native(내장 ros2cs, FastDDS)** — 본 Stage.
- SIM 은 `Simulator_v.R1.260701.H3`, `libros2cs_native.so` 내장(ROS2ForUnity). 외부 relay 불필요.
- ⚠️ **폐기된 접근**: rosbridge(9090) + `/client_count` 진단은 구버전 방식. 26.R1 에서는 지표 아님.

### ⚠️ 함정 1 — SIM 은 ROS2 Humble 이 **sourced 돼 있어야** Connect 가 된다 (실측, 반전됨)
SIM 내장 ros2cs 는 **비자체포함(standalone=0)** 빌드다. 즉 core ROS2 라이브러리를 번들하지 않고
호스트의 sourced ROS2 에서 가져온다.
- 근거: `Simulator_Data/Plugins/metadata_ros2cs.xml` → `<ros2>humble</ros2>` `<standalone>0</standalone>`.
- 근거: `env -i ldd libros2cs_native.so` → `librcl.so`/`librmw_implementation.so`/`librcutils.so` **not found**.
  `/opt/ros/humble/lib` 을 LD_LIBRARY_PATH 에 얹으면 **전부 해소**(실측).
- 실패 증상: 환경에 ROS2 가 없으면 Connect 시 `ros2cs metadata doesn't match currently sourced version`
  → `TypeInitializationException: ROS2.NativeRcl` → `Ros2Connect()` 실패(Disconnect 유지).
- **대응**: SIM 은 **ROS2 Humble 이 소싱된 환경**에서 실행해야 한다.
  `scripts/run_morai_launcher_nvidia.sh` 가 실행 '전' 에 `/opt/ros/humble/setup.bash` 를 소싱한다(자동).
  dyn-loader 는 exec 시점 LD_LIBRARY_PATH 를 고정하므로 반드시 이 래퍼로 실행.
- 검증: `tr '\0' '\n' < /proc/$(pgrep -f Simulator_v)/environ | grep /opt/ros` 에 항목이 있어야 정상.
- (앞선 "ROS 격리" 가설은 오진이었다. 정반대로 ROS2 가 **필요**하다.)

### ⚠️ 함정 2 — RMW 벤더는 FastDDS 여야 한다 (CycloneDDS 아님)
SIM Plugins 의 typesupport 는 **fastrtps 303개 / cyclonedds 0개** → SIM 은 FastDDS 로 퍼블리시한다.
- **리스너 RMW = `rmw_fastrtps_cpp`(기본)**. cyclonedds 로 바꾸면 RMW 불일치로 토픽 안 보임.
  (앞선 CycloneDDS 가설은 이 H3 빌드에선 틀림. env.sh 는 fastrtps 로 고정.)

### 핵심 전제 (이게 안 맞으면 토픽이 아예 안 보임)
1. **SIM 은 ROS2 미소싱 셸에서 실행** (래퍼가 자동 격리). ← 함정 1
2. **리스너 RMW = rmw_fastrtps_cpp** (기본). ← 함정 2
3. **ROS_DOMAIN_ID 일치**: 기본 0. SIM ROS2 설정에 Domain ID 필드가 있으면 값 일치.
4. **메시지 정의**: `morai_ros2_msgs` colcon 빌드(`~/avstack/ros2_ws`) — 타입 해석에 필요.
5. `ROS_LOCALHOST_ONLY=0` (CLAUDE.md: 1 금지).

→ 리스너 쪽 2·4·5 는 `scripts/stage05_ros2_native/env.sh` 가 일괄 처리(SIM 셸에서는 source 금지).

## 1. 준비 상태

- [x] `morai_ros2_msgs` colcon 빌드: `~/avstack/ros2_ws/install` (32 msg)
- [x] 리스너 RMW = rmw_fastrtps_cpp (ROS2 desktop 기본, 별도 설치 불필요)
- [x] 런처 ROS2 환경 격리(`run_morai_launcher_nvidia.sh`) — SIM 내장 ros2cs 충돌 방지
- [x] 스크립트: `scripts/stage05_ros2_native/{env,verify_topics,send_ctrl_cmd}.sh`, `offset_probe.py`
- [ ] **(사용자)** SIM 기동: `scripts/run_morai_launcher_nvidia.sh` → 4GB VRAM 맞는 지도(K-City 등, AVS-002)

## 2. 실행 순서 (clean start)

1. **SIM 기동** + 지도 로드 + Ego 스폰.
2. **SIM: Edit → Network Settings → ROS2**
   - Ego Network > Publisher: **Ego Vehicle Status** — Topic `/ego_vehicle_status`,
     Type `morai_ros2_msgs/msg/EgoVehicleStatus`, Hz 10~30
   - Sensor: **GPS**(`/gps`), 가능하면 IMU
   - (제어 테스트용) Ego Ctrl Cmd — Topic `/ctrl_cmd`(또는 `/ctrl_cmd_0`), Type `morai_ros2_msgs/msg/CtrlCmd`
   - Domain ID 필드 있으면 **0** 확인
   - **Connect 클릭** (설정 변경 시마다 다시 Connect)
3. **SIM: 시뮬레이션 Play** (Pause 면 hz≈0).
4. **터미널: 검증**
   ```
   bash scripts/stage05_ros2_native/verify_topics.sh
   ```
   - `ros2 topic list -t` 에 `/ego_vehicle_status`, `/gps`, `/clock` 등 표시
   - `/ego_vehicle_status` hz>0, echo --once 성공
   - `offset_probe.py` 로 sim/wall offset(mean/median/stdev)
   - 토픽/타입이 다르면: `EGO_TOPIC=/gps EGO_TYPE=GPSMessage bash .../verify_topics.sh`
5. (Gate 4, 선택) **제어 송신 테스트**: `bash scripts/stage05_ros2_native/send_ctrl_cmd.sh` → Ego 움직임 확인.

## 3. PASS / FAIL 판정

| # | 항목 | PASS 조건 |
|---|---|---|
| P1 | RMW/디스커버리 | fastrtps(기본) + domain 일치, `ros2 node list` 에 SIM 노드 표시 |
| P2 | 토픽 노출 | `topic list -t` 에 MORAI 토픽 ≥1 (typed) |
| P3 | 수신 | `/ego_vehicle_status` echo --once 성공, hz>0 |
| P4 | offset | `offset_probe.py` n≥20 로 mean/stdev 산출 |
| P5 | 기록 | stages.tsv 기록 + 증거 로그 |

**Stage 05 PASS** = P1·P2·P3·P4 + P5. offset 수치는 05.7 재현성 캘리브레이션 baseline.
(Gate 4 제어 테스트는 Stage 05.5/06 준비용 참고 — Stage 05 PASS 필수 아님.)

## 4. FAIL 트리아지 (증상별)

- **Connect 가 Disconnect 로 되돌아감** → SIM 을 ROS2 source 된 셸에서 실행(함정 1). 래퍼로만 실행.
- **토픽 자체가 안 보임** → 리스너 RMW 가 fastrtps 아님(함정 2), Domain ID 불일치, ROS2 설정 미적용.
- **토픽 보이는데 hz=0** → SIM Pause, 해당 Publisher 비활성, Frame rate 0, Ego/센서 미생성.
- **ego_vehicle_status 는 되는데 GPS 안 됨** → GPS 센서가 Ego 에 미장착, Sensor Network 미연결.
- **GPS 되는데 제어 안 됨** → `/ctrl_cmd` 토픽명/타입 불일치, Cmd Control 미설정, Ego control mode.
- 해결 안 되면 이슈 등록(`record_issue.sh`).

## 5. 기록 위치

- 증거: `~/avstack/runs/stage05_verify_<ts>.log`, `stage05_morai_msgs_build_<ts>.log`
- Stage 기록: `scripts/record_stage.sh 05_ros2_native PASS "<요약(offset 포함)>" "<로그>" "Stage 05.5"`

## 6. AVS-007 대응 경로

### 6-A. 버전 정합 테스트 (#2, 권장 실측 — 시스템 보존)
SIM ros2cs 빌드일(2023-03-31)의 Fast-DDS 계열을 별도 prefix 로 받아 **SIM 에만** 앞세운다.
```bash
# 1) 다운로드+추출 (네트워크 필요, sudo 불필요 — dpkg-deb -x 만):
bash scripts/stage05_ros2_native/fetch_fastdds_snapshot.sh
#    (날짜 변경 시: SNAPSHOT_DATE=2023-04-15 bash ...; 스냅샷 목록 http://snapshots.ros.org/humble/)
# 2) SIM 을 그 prefix 로 실행:
SOURCE_ROS2=1 FASTDDS_PREFIX=$HOME/avstack/ros2-fastdds-snap bash scripts/run_morai_launcher_nvidia.sh
# 3) 판정:
#    - SIM 이 startup 사망 없이 뜨고 Network Settings ROS2 Connect 유지 → H1 확정, native 진행.
#    - 여전히 std::bad_cast → H2(RTTI)/H3(매뉴얼) → 6-B(rosbridge) + MORAI 회신 대기.
```
검증: `/proc/$(pgrep -f Simulator_v)/environ` 의 LD_LIBRARY_PATH 에 prefix 가 앞서야 함;
`ldd`/`lsof` 로 SIM 이 2023 libfastrtps 를 로드했는지 확인 가능.

### 6-B. rosbridge 백업 경로 (ABI 무관)
SIM WebSocket(RosBridgeClient)은 ros2cs/DDS 를 안 타므로 AVS-007 과 무관하게 동작.
```bash
# host: rosbridge_server (별도 터미널, host ROS2=fastrtps)
bash scripts/stage05_ros2_native/run_rosbridge.sh
# SIM: 일반 실행(ROS2 미소싱). Network Settings=ROS(bridge), Bridge IP=127.0.0.1:9090, Connect.
# 확인: 또 다른 터미널
bash scripts/stage05_ros2_native/verify_topics.sh
```
※ 이 경우 토픽은 host rosbridge_server 가 재발행한 DDS. offset 은 /clock 또는 header stamp 로 측정.

## 참고
- MORAI ROS2 msgs: https://github.com/MORAI-Autonomous/MORAI-ROS2_morai_msgs
- 26.R1.H1(2026-05-04) hotfix: Ego Ctrl cmd 기본 Topic 명 수정 포함 → 가능하면 H1 이상 사용.
- Docker 판단은 Stage 05 통과 후, 실제 설치는 Stage 06 착수 시점(로드맵 3장).
