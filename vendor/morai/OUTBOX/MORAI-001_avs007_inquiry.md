# MORAI 문의 — 26.R1.H3 ROS2 연동 (내부 ID: MORAI-001 / 관련: AVS-007)

그대로 복사해 MORAI 기술지원에 보낼 수 있는 문의문. (한국어/영문 병기)

## 1. 요약 (3줄 이내)
<!-- 원 초안에 3줄 요약 없음 — 발송 전 작성. 증거 보강은 D1~D4 실측 후 별도 작업. -->

## 2. 환경
- MORAI SIM: Drive **26.R1.H3** (`Simulator_v.R1.260701.H3_Linux`)
- Host: Ubuntu 22.04.5, ROS2 **Humble** (apt, 2026-06 sync). `rmw_fastrtps_cpp 6.2.10`, `fastrtps 2.6.11`.
- 목표: Ego 상태·센서 토픽을 host ROS2 Humble로 수신(외부 알고리즘/Autoware 연동).

## 3. 재현 절차
<!-- 원 초안에 번호 매긴 재현 절차 없음 — 발송 전 작성(3회 재현 명시). -->

## 4. 실측 증거

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
  [id:/Ego_topic] publish: Message type morai_msgs/EgoVehicleStatus does not have a field header.seq
  [id:/tf]        publish: Message type tf2_msgs/TFMessage does not have a field transforms.header.seq
  ```
  누락 필드 = **`header.seq`**. 이는 **ROS1 `std_msgs/Header`의 `seq`**(ROS2에서 제거된 필드)입니다.
  즉 **SIM의 ROS bridge가 ROS1 헤더(seq 포함) 포맷으로 발행**하여 ROS2 rosbridge_suite가 거부합니다.
  → ROS2 환경에서 rosbridge로 쓰려면 SIM이 **ROS2 헤더(seq 없음)로 발행**하도록 옵션이 필요합니다.

저장소 내 근거 경로 (내부 추적용 — 발송본에서는 경로 제거 가능):
- `runbooks/avs-007_ros2_native_report.md`, `~/avstack/logs/avs007_ros2cs_abi_mismatch_20260703.md`

## 5. 질문 (번호, 예/아니오로 답할 수 있게)
1. 26.R1.H3의 ROS2 Native(ros2cs)를 Linux/Humble에서 사용하려면 **정확히 어떤 환경**이 필요합니까?
   (요구 ROS2 배포/버전, `librmw_fastrtps_cpp std::bad_cast` 회피 방법, 또는 **standalone ros2cs 빌드** 제공 가능 여부)
2. rosbridge(ROS 모드)로 쓸 경우, SIM이 기대하는 **rosbridge_suite 버전**과 **정확한 morai 메시지 정의 세트**
   (26.R1.H3 대응)를 알려주십시오. 표준 tf 필드(`transform` vs `transforms`) 불일치 원인도 문의합니다.
3. 26.R1.H3에서 **검증된 완전한 ROS2 연동 환경**(권장 OS·ROS2 버전·설치 절차 또는 docker 이미지)이 있습니까?

## 6. 요청 사항 / 기능 제안 (선택)
<!-- 원 초안에 별도 요청 절 없음 — 질문 1의 'standalone ros2cs 빌드', 질문 2의 'ROS2 헤더 발행 옵션'이
     기능 요청 성격. 발송 전 분리 검토(추가 작성은 별도 작업). -->
