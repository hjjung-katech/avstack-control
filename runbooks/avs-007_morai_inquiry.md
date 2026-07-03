# MORAI 문의 초안 — 26.R1.H3 ROS2 연동 (AVS-007)

그대로 복사해 MORAI 기술지원에 보낼 수 있는 문의문. (한국어/영문 병기)

---

## 환경
- MORAI SIM: Drive **26.R1.H3** (`Simulator_v.R1.260701.H3_Linux`)
- Host: Ubuntu 22.04.5, ROS2 **Humble** (apt, 2026-06 sync). `rmw_fastrtps_cpp 6.2.10`, `fastrtps 2.6.11`.
- 목표: Ego 상태·센서 토픽을 host ROS2 Humble로 수신(외부 알고리즘/Autoware 연동).

## 증상 (두 경로 모두 실패)

**A. ROS2 Native (Network Settings의 ROS2)**
- Connect 시 SIM이 즉시 종료. Player.log:
  ```
  ROS2 version in 'ros2cs' metadata doesn't match currently sourced version.
  [rcl]: failed to load shared library 'librmw_fastrtps_cpp.so' due to std::bad_cast,
         at ./src/functions.cpp:65, exiting with 1
  ```
- 확인: SIM `metadata_ros2cs.xml` = `<ros2>humble</ros2> <standalone>0</standalone>` (2023-03-31, ros2cs 1.3.0).
  standalone=0 이라 host ROS2 필요. **host에 ROS2 Humble을 소싱하면 위 std::bad_cast로 종료**, 소싱 안 하면 `librcl.so not found`.
- **버전 정합 시도(무효)**: 2023-03-13 스냅샷의 Fast-DDS(2.6.4/rmw 6.2.2/typesupport 2.2.0)를 SIM에만 적용해도
  **동일한 std::bad_cast**. (동일 라이브러리로 일반 rclpy 프로세스는 정상.) → host ROS2 버전 문제가 아님.

**B. rosbridge (Network Settings의 ROS)**
- Simulator/Ego/Sensor를 ROS(bridge) 127.0.0.1:9090으로 연결 성공(client_count>0), `morai_msgs` 패키지로
  토픽 생성됨(/Ego_topic 등). **그러나 데이터가 하나도 수신 안 됨.**
- rosbridge_server(ros-humble-rosbridge-suite 2.0.7) 로그: SIM의 publish를 **필드 불일치로 전부 거부**:
  ```
  [id:/Ego_topic] publish: Message type morai_msgs/EgoVehicleStatus does not have a field ...
  [id:/tf]        publish: Message type tf2_msgs/TFMessage does not have a field transform
  ```
  표준 `tf2_msgs/TFMessage`까지 걸림(SIM이 `transform` 전송, 표준은 `transforms`).

## 질문
1. 26.R1.H3의 ROS2 Native(ros2cs)를 Linux/Humble에서 사용하려면 **정확히 어떤 환경**이 필요합니까?
   (요구 ROS2 배포/버전, `librmw_fastrtps_cpp std::bad_cast` 회피 방법, 또는 **standalone ros2cs 빌드** 제공 가능 여부)
2. rosbridge(ROS 모드)로 쓸 경우, SIM이 기대하는 **rosbridge_suite 버전**과 **정확한 morai 메시지 정의 세트**
   (26.R1.H3 대응)를 알려주십시오. 표준 tf 필드(`transform` vs `transforms`) 불일치 원인도 문의합니다.
3. 26.R1.H3에서 **검증된 완전한 ROS2 연동 환경**(권장 OS·ROS2 버전·설치 절차 또는 docker 이미지)이 있습니까?

## 첨부 근거 (사내)
- `runbooks/avs-007_ros2_native_report.md`, `~/avstack/logs/avs007_ros2cs_abi_mismatch_20260703.md`
