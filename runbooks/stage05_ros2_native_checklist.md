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
- **사용자·Autoware ↔ SIM**: ① ROS2 Native(내장 ros2cs, FastDDS) — **AVS-007 로 불가**,
  ② **ROS(rosbridge, 9090)** — 연결됨, `header.seq` 패치가 남음(§6-B). **현재 유효 경로는 ② 뿐.**
- SIM 은 `Simulator_v.R1.260701.H3`, `libros2cs_native.so` 내장(ROS2ForUnity).

### 확정 사실 — native(ros2cs) 는 현재 어떤 조합으로도 불가 (2026-07-03 실측)
SIM ros2cs 는 **standalone=0**(humble 2023-03-31 빌드): core ROS2 lib 을 host 에서 가져와야 한다.
그러나:
- **host ROS2 미소싱**(런처 기본): SIM 은 정상 시작하나, ROS2 Connect 시 `librcl not found`
  → `TypeInitializationException: ROS2.NativeRcl` → Disconnect 유지.
- **host ROS2 소싱**(`SOURCE_ROS2=1`): SIM 이 **startup 에서 `librmw_fastrtps_cpp std::bad_cast` 로 즉시 종료**.
- **2023 fastrtps 로 버전 정합**(`FASTDDS_PREFIX`): prefix 전파 확인됐음에도 **동일 bad_cast → H1(버전) 반증**.
  동일 2023 libs 는 일반 rclpy 프로세스에서 정상 → 원인은 SIM 의 ros2cs/Unity 로딩(H2 RTLD/RTTI 추정, H3 가능).
- **∴ 켜도, 꺼도, 맞춰도 안 됨. native 는 MORAI 지원 필요**(`vendor/morai/OUTBOX/MORAI-001_avs007_inquiry.md` 발송).
- 런처 기본은 **ROS2 미소싱**(SIM 정상 시작용). `SOURCE_ROS2=1`/`FASTDDS_PREFIX` 는 실험용 opt-in 으로만 유지.

### 리스너 쪽 상수 (native 든 rosbridge 든 공통)
1. **리스너 RMW = rmw_fastrtps_cpp**(기본). SIM typesupport 가 전부 fastrtps(303/0) — cyclonedds 아님.
2. **ROS_DOMAIN_ID = 0** 일치, `ROS_LOCALHOST_ONLY=0`(CLAUDE.md: 1 금지).
3. **메시지 정의 2종** colcon 빌드(`~/avstack/ros2_ws`):
   - `morai_ros2_msgs`(원본), **`morai_msgs`(리네임 복제)** — SIM(rosbridge)이 `morai_msgs/...` 타입명으로
     advertise 하므로 필수. 단 필드 정의는 ROS2 저장소 기준이라 **SIM(ROS1 포맷)과 다를 수 있음** —
     불일치 시 MORAI-ROS_morai_msgs(ROS1 저장소) 정의로 재생성.
→ `scripts/stage05_ros2_native/env.sh` 가 일괄 처리.

## 1. 준비 상태

- [x] `morai_ros2_msgs` + `morai_msgs`(리네임) colcon 빌드: `~/avstack/ros2_ws/install`
- [x] 리스너 RMW = rmw_fastrtps_cpp (ROS2 desktop 기본)
- [x] 스크립트: `scripts/stage05_ros2_native/{env,verify_topics,send_ctrl_cmd,run_rosbridge,fetch_fastdds_snapshot}.sh`, `offset_probe.py`
- [ ] **rosbridge `header.seq` 패치** (§6-B — 다음 세션 1차 관문)
- [ ] **(사용자)** SIM 기동: `scripts/run_morai_launcher_nvidia.sh` → 4GB VRAM 맞는 지도(K-City 등, AVS-002)

## 2. 실행 순서 (rosbridge 경로 — 현재 유일한 유효 경로)

0. **(1차 관문) rosbridge `header.seq` 패치** — §6-B. 패치 없으면 토픽은 떠도 데이터 0.
1. **터미널 A**: `bash scripts/stage05_ros2_native/run_rosbridge.sh` (9090 대기)
2. **SIM 기동**(일반 모드, `scripts/run_morai_launcher_nvidia.sh`) + 지도 로드 + Ego 스폰.
3. **SIM: Edit → Network Settings** — **Simulator/Ego(차량)/Sensor 세 네트워크 전부**:
   - 프로토콜 **ROS**(bridge; ROS2 아님), **Bridge IP=127.0.0.1, Port=9090**
   - Ego: **Ego Vehicle Status** publisher — Topic **`/Ego_topic`**, Type `morai_msgs/EgoVehicleStatus`(기본값)
   - Sensor: **GPS**(`/gps`)
   - 각 네트워크 **Connect** (⚠️ 실측: 세 네트워크를 각각 연결해야 전체 토픽이 뜸 —
     Simulator 만 연결하면 `/ego_setting` 등만 보이고 `/Ego_topic`/`/gps` 안 뜸)
4. 시뮬레이션은 별도 Play 버튼 없이 **상시 실행**(MORAI Drive 실측). ego 물리 작동이면 running.
5. **터미널 B: 검증**
   ```
   bash scripts/stage05_ros2_native/verify_topics.sh   # 기본 EGO_TOPIC=/Ego_topic
   ```
   - `topic list -t` 에 `/Ego_topic [morai_msgs/msg/EgoVehicleStatus]`, `/gps`, `/clock` 등
   - `/Ego_topic` hz>0 + echo --once 성공 (**데이터가 흘러야** 함 — 광고만으로는 부족)
   - `offset_probe.py` 로 sim/wall offset(mean/median/stdev)
6. (선택) **제어 송신 테스트**: `bash scripts/stage05_ros2_native/send_ctrl_cmd.sh` → Ego 움직임 확인.

## 3. PASS / FAIL 판정

| # | 항목 | PASS 조건 |
|---|---|---|
| P1 | 연결 | 세 네트워크 모두 rosbridge 접속(client_count>0), `/Ego_topic` typed 로 생성 |
| P2 | 토픽 노출 | `topic list -t` 에 MORAI 토픽 ≥1 (typed) |
| P3 | 수신 | `/Ego_topic` **데이터 수신**(echo --once 성공, hz>0) — 광고만으로는 불충분 |
| P4 | offset | `offset_probe.py` n≥20 로 mean/stdev 산출 |
| P5 | 기록 | stages.tsv 기록 + 증거 로그 |

**Stage 05 PASS** = P1·P2·P3·P4 + P5. offset 수치는 05.7 재현성 캘리브레이션 baseline.
(제어 테스트는 Stage 05.5/06 준비용 참고 — Stage 05 PASS 필수 아님.)

## 4. FAIL 트리아지 (증상별, 실측 기반)

- **토픽 자체가 안 보임** → 해당 네트워크(Ego/Sensor)가 rosbridge 에 미연결(3개 각각 Connect), 9090 불일치.
- **토픽 보이는데 데이터 0 + rosbridge 로그 `does not have a field header.seq`** → §6-B 패치 미적용(1차 관문).
- **header.seq 외 다른 필드 에러** → msg 정의가 SIM(ROS1)과 불일치 → MORAI-ROS_morai_msgs(ROS1 저장소)
  정의로 `morai_msgs` 재생성(2차 관문).
- **`/Ego_topic` 은 되는데 GPS 안 됨** → GPS 센서 Ego 미장착, Sensor Network 미연결.
- **GPS 되는데 제어 안 됨** → `/ctrl_cmd` 토픽/타입 불일치, Cmd Control 미설정, Ego control mode.
- 해결 안 되면 이슈 등록(`record_issue.sh`).

## 5. 기록 위치

- 증거: `~/avstack/runs/stage05_verify_<ts>.log`, `stage05_morai_msgs_build_<ts>.log`
- Stage 기록: `scripts/record_stage.sh 05_ros2_native PASS "<요약(offset 포함)>" "<로그>" "Stage 05.5"`

## 6. AVS-007 대응 경로 (2026-07-03 실측 반영)

### 6-A. ~~버전 정합 테스트~~ — **실시됨, H1 반증. 재시도 금지**
2023-03-13 스냅샷 Fast-DDS(2.6.4)를 `FASTDDS_PREFIX` 로 SIM 에 전달(전파 /proc 확인)했으나
**동일 std::bad_cast** → 버전은 원인이 아님. 동일 libs 로 rclpy 는 정상. **native 는 MORAI 지원 대기**
(`vendor/morai/OUTBOX/MORAI-001_avs007_inquiry.md`). `fetch_fastdds_snapshot.sh`/`SOURCE_ROS2`/`FASTDDS_PREFIX` 는
회신 후 재검증용으로만 유지.

### 6-B. rosbridge 경로 — 주 경로. **1차 관문 = `header.seq` 패치**
연결·토픽 생성까지 실측 성공. 데이터가 0 인 이유: SIM 이 **ROS1 헤더(`header.seq`)** 로 발행
→ ROS2 rosbridge_suite 가 미지 필드로 거부(`EgoVehicleStatus ... does not have a field header.seq`,
표준 `tf2_msgs` 의 `transforms.header.seq` 포함).
```bash
# 0) [1차 관문] rosbridge_library message_conversion 이 미지 필드를 무시하도록 패치
#    (또는 수신 JSON 에서 header.seq strip). 패치 후 rosbridge 재시작.
# 1) host: rosbridge_server
bash scripts/stage05_ros2_native/run_rosbridge.sh
# 2) SIM: 일반 실행(런처 기본). Network Settings 의 Simulator/Ego/Sensor 전부
#    ROS(bridge) 127.0.0.1:9090 로 Connect.
# 3) 검증:
bash scripts/stage05_ros2_native/verify_topics.sh
# 4) header.seq 외 필드 에러가 더 나오면 [2차 관문]: MORAI-ROS_morai_msgs(ROS1) 정의로
#    morai_msgs 재생성 후 재시도.
```
※ 토픽은 host rosbridge_server 가 재발행한 DDS. offset 은 `/Ego_topic` header stamp 로 측정.

## 참고
- MORAI ROS2 msgs: https://github.com/MORAI-Autonomous/MORAI-ROS2_morai_msgs
- 26.R1.H1(2026-05-04) hotfix: Ego Ctrl cmd 기본 Topic 명 수정 포함 → 가능하면 H1 이상 사용.
- Docker 판단은 Stage 05 통과 후, 실제 설치는 Stage 06 착수 시점(로드맵 3장).
