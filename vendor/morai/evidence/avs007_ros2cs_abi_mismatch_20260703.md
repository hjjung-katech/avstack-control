# AVS-007 증거 — MORAI ros2cs(2023 Humble) ↔ host Humble(2026) ABI 불일치

날짜: 2026-07-03. Stage 05(ROS2 Native) 블로커.

## 결론
MORAI SIM 26.R1.H3 의 ROS2 Native(ros2cs)를 host ROS2 Humble 로 붙이면, SIM 이 시작
직후 `std::bad_cast` 로 종료한다. SIM ros2cs 는 **Humble 2023-03-31** 빌드인데 host Humble 은
**2026-06-05 패치**라 FastDDS/typesupport ABI 가 어긋난다.

## 근거
- `Simulator_Data/Plugins/metadata_ros2cs.xml`: `<ros2>humble</ros2>` `<standalone>0</standalone>`
  `<version><desc>1.3.0</desc><date>2023-03-31</date></version>`
- `metadata_ros2_for_unity.xml`: 동일(humble, 1.3.0, 2023-03-31).
- SIM Plugins: rosidl_typesupport **fastrtps 303개** 번들, 그러나 libfastrtps/libfastcdr/librmw
  **미번들** → host /opt/ros 의존(standalone=0).
- `env -i ldd libros2cs_native.so`: librcl.so/librmw_implementation.so/librcutils.so **not found**;
  `/opt/ros/humble/lib` 을 얹으면 해소.
- ROS2 소싱 후 SIM 시작 시 Player.log:
  ```
  [ERROR][rcl]: failed to load shared library 'librmw_fastrtps_cpp.so' due to std::bad_cast,
                at ./src/functions.cpp:65, exiting with 1
  ```
  (SIM 이 번들 typesupport(2023)를 preload 한 뒤 host rmw(2026)를 로드하다 충돌.)
- host: libfastrtps.so.2.6.11, ros-humble-rmw-fastrtps-cpp 6.2.10-1jammy.20260605.

## 증상 요약
- ROS2 미소싱(기본): SIM 정상 시작. 그러나 Network Settings ROS2 Connect 시 ros2cs NativeRcl
  예외(librcl not found) → Disconnect 유지.
- ROS2 소싱(SOURCE_ROS2=1): SIM 이 startup 에서 std::bad_cast 로 종료(Start 안 됨).
- 즉 host Humble 버전으로는 native 를 켤 수도, 끌 수도 없는 교착.

## 후보 대응
1. **rosbridge 경로**: SIM 의 RosBridgeClient(WebSocket)는 ros2cs/DDS ABI 를 안 탄다. host 에서
   `rosbridge_server` 실행 → SIM Network Settings 를 ROS(bridge)로 Connect → 토픽을 host ROS2 로
   재발행. 이 환경에서 실제로 연결됐던 경로(client_count>0). **가장 현실적.**
2. **host ROS2 Humble 을 SIM 빌드시점(2023-03)에 맞춰 다운그레이드/핀**: apt 는 최신만 제공 →
   구 deb 핀 또는 소스 빌드 필요. 리스크 큼.
3. **MORAI 문의**: 26.R1.H3 ros2cs 가 요구하는 정확한 ROS2 Humble 패치/버전, 또는 standalone
   ros2cs / 지원 docker 제공 여부.

## 참고
- 런처는 기본 ROS2 미소싱으로 되돌림(SIM 정상 시작). 실험 시 `SOURCE_ROS2=1`.
- ros2cs standalone build 개념: metadata standalone=1 이면 자체포함(호스트 ROS2 불필요).
  현재 SIM 은 standalone=0.

---

## 실험 갱신 (2026-07-03 21:xx) — H1(버전 불일치) **반증**

#2(버전 정합) 실측 결과:
- `fetch_fastdds_snapshot.sh SNAPSHOT_DATE=2023-03-13` → Fast-DDS 2.6.4 / fastcdr 1.0.24 /
  rmw_fastrtps_cpp 6.2.2 / typesupport 2.2.0 추출(SIM ros2cs 빌드일 근접).
- `SOURCE_ROS2=1 FASTDDS_PREFIX=...` 로 SIM 실행 → SIM environ 캡처(PID 377241):
  LD_LIBRARY_PATH 맨 앞에 fastdds-snap prefix 확인(전파 정상).
- 그럼에도 **동일한 `librmw_fastrtps_cpp std::bad_cast` 로 SIM startup 사망**(Player.log 21:07 세션).
- 대조: 동일 2023 libs 를 얹은 rclpy 프로세스는 정상(`rclpy.init()` OK), 실제로 2023
  librmw_fastrtps_cpp + libfastrtps.so.2.6.4 를 로드함(maps 확인).

**결론**: 버전(2023 vs 2026)은 원인이 아니다 → **H1 반증**. 실패는 SIM의 ros2cs/Unity 로딩
환경 특유(H2 RTTI/dlopen 가시성, 또는 H3 MORAI 플러그인 구조). host ROS2 다운그레이드로 해결 불가.

**방향 갱신**: (1) rosbridge 우회로 Stage 05 실질 진행(ABI 무관, 연결 실적 있음).
(2) native 는 MORAI 지원 필요 — standalone ros2cs 빌드 제공 또는 정확한 로딩 절차. (문의 유지)

---

## rosbridge 경로 실측 (2026-07-03 22:xx) — 연결 OK, 데이터 포맷 불일치로 차단

- SIM Network Settings 를 ROS(bridge)/127.0.0.1:9090 으로 Simulator/Ego/Sensor 모두 연결 →
  rosbridge_server 에 접속(client_count 32).
- 타입 해결 위해 `morai_msgs` ROS2 패키지 빌드(morai_ros2_msgs 리네임). → rosbridge 가 토픽 생성:
  /Ego_topic, /gps, /Object_topic, /ctrl_cmd, /CollisionData, /sim/process/state 등 대량 advertise.
- **그러나 데이터가 하나도 안 흐름.** /rosout 로그: rosbridge 가 SIM 의 publish 를 **필드 불일치로 전부 거부**:
  ```
  [id:/Ego_topic] publish: Message type morai_msgs/EgoVehicleStatus does not have a field ...(truncated)
  [id:/tf] publish: Message type tf2_msgs/TFMessage does not have a field transform
  [id:/Object_topic] ... morai_msgs/ObjectStatusList does not have ...
  [id:/CollisionData] ... morai_msgs/CollisionData does not have ...
  ```
- **표준 tf2_msgs/TFMessage 까지 걸림**(SIM 이 `transform` 필드 전송, 표준은 `transforms`) →
  단순 msg 버전 불일치를 넘어, SIM 의 ROS-bridge 직렬화 포맷이 현 rosbridge_suite(ROS2 2.0.7)와 불일치.
- /Ego_topic QoS=RELIABLE/TRANSIENT_LOCAL, Publisher=rosbridge, **수신 메시지 0**(latch 도 없음=한번도 발행 안 됨).

**결론**: rosbridge 경로도 이 환경에서 데이터 전달 불가(포맷/버전 불일치). native(AVS-007 ABI)와 함께
**두 경로 모두 MORAI 26.R1.H3 ↔ host Humble(2026)/rosbridge_suite(2026) 버전 불일치로 차단**.
→ MORAI 지원 필요: (a) 호환 ROS2 버전/standalone ros2cs, (b) 호환 rosbridge_suite 버전 또는 정확한 msg 정의 세트.

---

## rosbridge 정밀 원인 (2026-07-03 22:xx) — `header.seq` (ROS1 헤더), **FIXABLE**

전체 에러(잘림 해소):
```
morai_msgs/EgoVehicleStatus does not have a field header.seq
tf2_msgs/TFMessage        does not have a field transforms.header.seq
```
누락 필드 = **`header.seq`**. ROS1 `std_msgs/Header`의 `uint32 seq` 는 **ROS2 에서 제거됨**
(ROS2 Header = stamp, frame_id). MORAI ROS-bridge 가 **ROS1 헤더(seq 포함)** 로 전송 → ROS2
rosbridge_suite(2.0.7) 가 미지 필드로 **엄격 거부**.

→ **근본적 포맷 불일치가 아니라 단일 필드(`header.seq`) 문제.** rosbridge 가 unknown 필드를
무시/strip 하도록 하면(구버전 rosbridge 관용, 또는 message_conversion 패치, 또는 header.seq 제거)
EgoVehicleStatus·tf 포함 전 토픽 데이터가 흐를 가능성 높음. **rosbridge 경로는 FIXABLE.**
(앞선 "rosbridge 근본 차단" 서술을 이 정밀 원인으로 정정.)
