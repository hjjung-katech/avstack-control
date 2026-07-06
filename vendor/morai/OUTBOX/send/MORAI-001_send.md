# MORAI 문의 — 26.R1.H3 ROS2 연동

## 1. 요약 (3줄 이내)
26.R1.H3를 host ROS2 Humble로 붙이는 두 경로(Native/rosbridge)가 모두 데이터 수신 단계에서 막힙니다.
ROS2 Native는 host ROS2 소싱 실행 시 SIM이 **startup에서** `librmw_fastrtps_cpp std::bad_cast`로 즉시 종료합니다(ros2cs standalone=0, humble 2023-03-31 빌드; host 버전 정합으로도 미해결).
rosbridge(ROS 모드)는 연결·토픽 생성까지 되나 SIM이 ROS1 헤더(`header.seq`)로 발행해 ROS2 rosbridge_suite가 전 메시지를 거부, 데이터가 0입니다.

## 2. 환경
- MORAI SIM: Drive **26.R1.H3** (`Simulator_v.R1.260701.H3_Linux`)
- Host: Ubuntu 22.04.5, ROS2 **Humble** (apt, 2026-06 sync). `rmw_fastrtps_cpp 6.2.10`, `fastrtps 2.6.11`.
- 목표: Ego 상태·센서 토픽을 host ROS2 Humble로 수신(외부 알고리즘/Autoware 연동).

## 3. 재현 절차
**A. ROS2 Native (host ROS2 소싱 실행 시 startup 크래시)**
1. host ROS2 Humble 소싱 상태로 SIM 기동 → 지도 로드 → Start.
2. → SIM이 **startup(ros2cs preload)에서 즉시 종료**. Player.log에 §4-A의 std::bad_cast.
3. (대조) 미소싱 기동 시 SIM은 정상 뜨나 ROS2 Connect에서 `librcl not found` → Disconnect.
→ **3회 재현 (2026-07-06)**. DDS 계층: 종료까지 SIM이 RTPS(UDP 74xx) 미바인딩 = participant 미생성.

**B. rosbridge**
1. host에서 `rosbridge_server`(rosbridge_suite 2.0.7) 기동.
2. SIM Network Settings의 Simulator/Ego/Sensor를 ROS(bridge) 127.0.0.1:9090으로 각각 Connect.
3. → 토픽은 생성(typed)되나 수신 데이터 0. rosbridge_server 로그에 §4-B의 `header.seq` 거부 수만 건.
→ **3회 재현 (2026-07-06)**.

- 재현성: **결정론적으로 재현됨** — 두 경로 모두 확률적 요소가 없으며 Player.log/rosbridge 로그(§4)로 직접 검증 가능.

## 4. 실측 증거

**A. ROS2 Native (Network Settings의 ROS2)**
- host ROS2 소싱 실행 시 SIM이 **startup(ros2cs preload)에서 즉시 종료**. Player.log:
  ```
  ROS2 version in 'ros2cs' metadata doesn't match currently sourced version.
  [rcl]: failed to load shared library 'librmw_fastrtps_cpp.so' due to std::bad_cast,
         at ./src/functions.cpp:65, exiting with 1
  ```
- 확인: SIM `metadata_ros2cs.xml` = `<ros2>humble</ros2> <standalone>0</standalone>` (2023-03-31, ros2cs 1.3.0).
  standalone=0 이라 host ROS2 필요. **host에 ROS2 Humble을 소싱하면 위 std::bad_cast로 종료**, 소싱 안 하면 `librcl.so not found`.
- **DDS 계층 실측 (2026-07-06, 3회)**: 기동~종료 구간 SIM이 RTPS discovery(UDP 74xx) 포트를 바인딩하지 않음
  → **DDS participant 미생성** (ss 폴링 0건; rmw 로드 실패로 participant 생성 자체 불가). ss 로그 첨부 가능.
- **버전 정합 시도(무효)**: 2023-03-13 스냅샷의 Fast-DDS(2.6.4/rmw 6.2.2/typesupport 2.2.0)를 SIM에만 적용해도
  **동일한 std::bad_cast**. (동일 라이브러리로 일반 rclpy 프로세스는 정상.) → host ROS2 버전 문제가 아님.

**B. rosbridge (Network Settings의 ROS)**
- Simulator/Ego/Sensor를 ROS(bridge) 127.0.0.1:9090으로 연결 성공(client_count>0), `morai_msgs` 패키지로
  토픽 생성됨(/Ego_topic 등). **그러나 데이터가 하나도 수신 안 됨.**
- rosbridge_server(ros-humble-rosbridge-suite 2.0.7) 로그: SIM의 publish를 **필드 불일치로 전부 거부**:
  ```
  [id:/Ego_topic] publish: Message type morai_msgs/EgoVehicleStatus does not have a field header.seq
  [id:/tf]        publish: Message type tf2_msgs/TFMessage does not have a field transforms.header.seq
  ```
  누락 필드 = **`header.seq`**. 이는 **ROS1 `std_msgs/Header`의 `seq`**(ROS2에서 제거된 필드)입니다.
  즉 **SIM의 ROS bridge가 ROS1 헤더(seq 포함) 포맷으로 발행**하여 ROS2 rosbridge_suite가 거부합니다.
  → ROS2 환경에서 rosbridge로 쓰려면 SIM이 **ROS2 헤더(seq 없음)로 발행**하도록 옵션이 필요합니다.

## 5. 질문 (번호, 예/아니오로 답할 수 있게)
1. 26.R1.H3의 ROS2 Native(ros2cs)를 Linux/Humble에서 사용하려면 **정확히 어떤 환경**이 필요합니까?
   (요구 ROS2 배포/버전, `librmw_fastrtps_cpp std::bad_cast` 회피 방법, 또는 **standalone ros2cs 빌드** 제공 가능 여부)
2. rosbridge(ROS 모드)로 쓸 경우, SIM이 기대하는 **rosbridge_suite 버전**과 **정확한 morai 메시지 정의 세트**
   (26.R1.H3 대응)를 알려주십시오. 표준 tf 필드(`transform` vs `transforms`) 불일치 원인도 문의합니다.
3. 26.R1.H3에서 **검증된 완전한 ROS2 연동 환경**(권장 OS·ROS2 버전·설치 절차 또는 docker 이미지)이 있습니까?

## 6. 요청 사항 / 기능 제안
이 블로커의 직접 해제 수단으로 다음 두 가지를 요청합니다:
1. **standalone ros2cs 빌드 제공** — host ROS2 버전 의존 없이 동작하는 자체포함(standalone=1) ros2cs 빌드를 제공해 주시면 ROS2 Native 연동이 가능합니다.
2. **ROS 브리지의 ROS2 헤더 발행 옵션** — rosbridge 경로에서 SIM이 ROS1 헤더(`header.seq`) 대신 ROS2 표준 헤더(seq 없음)로 발행하는 옵션을 제공해 주시면 수신이 가능합니다.
