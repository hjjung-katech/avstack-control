# MORAI 검증 결과 — 26.R1.H3 ROS2 연동 "morai_msgs 미소싱" 진단 재검증 (내부 ID: MORAI-001 후속 / 관련: AVS-007, T-24)

<!-- INTERNAL: 재회신 첨부용 기술상세 문서(지난번 KATECH-SIM-ROS2_기술상세.pdf 후속).
     이메일 본문은 MORAI-001_t24_reply_email.md 별도. 스레드: Re: [과제협조] ... (Ref KATECH-SIM-ROS2).
     검증 원장: runbooks/t24_vendor_diag_verification.md §3-4 (분기 C). SENT 동결 시 INTERNAL 블록 제거. -->

Ref: **KATECH-SIM-ROS2** (2026-07-06 문의의 후속 / 2026-07-08 회신 "morai_msgs 미소싱, 환경 설정 확인 권장"에 대한 검증 결과)

## 1. 요약 (3줄 이내)
권장해 주신 대로 ROS2용 morai_msgs를 SIM 버전 정합(태그 `26.R1`)으로 빌드·소싱하고, 소싱이 SIM 프로세스에 반영됐음을 실물(environ)로 확인한 상태에서 두 경로를 재시험했습니다.
**결과: 두 경로 모두 기존과 동일하게 실패**합니다 — Native는 startup `std::bad_cast`(메시지 사용 이전인 rcl/rmw 초기화 계층), rosbridge는 `header.seq` 필드 불일치 전량 거부(표준 `tf2_msgs` 포함).
따라서 원인은 저희 환경의 msgs 소싱 여부가 아닌 것으로 판단되며, 내부 재현·확인하신 환경 정보를 요청드립니다.

## 2. 검증 환경 (권장사항 반영 내역)
- MORAI SIM: Drive **26.R1.H3** (`Simulator_v.R1.260701.H3_Linux`) / Host: Ubuntu 22.04.5, ROS2 Humble(apt), rmw_fastrtps_cpp 6.2.10 — 2026-07-06 문의와 동일.
- **morai_msgs 준비**: 공식 리포 `MORAI-Autonomous/MORAI-ROS2_morai_msgs`를 SIM 버전과 정합한 **태그 `26.R1`(commit c84d648)** 로 체크아웃, colcon 빌드 후 오버레이 소싱.
  - 소싱 전 `ros2 interface list` 기준 morai 인터페이스 **0건 → 소싱 후 76건**(EgoVehicleStatus, CtrlCmd 등) 확인.
  - SIM이 rosbridge에 요구하는 타입 문자열이 `morai_msgs/*`이므로, 공식 패키지명(`morai_ros2_msgs`)과 함께 `morai_msgs` 명칭 패키지도 동일 소스로 빌드해 양쪽 모두 해석되게 했습니다.
- **소싱 반영 증거**: SIM 부모 프로세스(런처)의 `/proc/<pid>/environ` 캡처 — `AMENT_PREFIX_PATH`에 morai_msgs 오버레이 포함 (첨부 1).

## 3. 재시험 결과 (2026-07-10 실측)

**A. ROS2 Native — 소싱 상태에서 동일 크래시**
- morai_msgs 오버레이 소싱 상태로 SIM 기동 → Start 시 기존과 동일하게 **startup에서 즉시 종료**:
  ```
  [rcl]: Error getting RMW implementation identifier ... 'failed to load shared library
  'librmw_fastrtps_cpp.so' due to std::bad_cast, at ./src/functions.cpp:65', exiting with 1
  ```
  (첨부 2 Player.log 547행)
- 크래시 지점은 **rcl/rmw 초기화 계층**으로, 메시지 패키지 참조 이전 단계입니다. 종료까지 SIM은 RTPS(UDP 74xx) 미바인딩 = DDS participant 미생성(2026-07-06 실측과 동일).

**B. rosbridge — 26.R1 정합 msgs 소싱 상태에서 동일 거부**
- 연결(client_count 33)·토픽 23종 생성은 정상이나 **수신 데이터 0건**.
- rosbridge_server(ros-humble-rosbridge-suite 2.0.7)가 SIM 발행을 `header.seq` 불일치로 **전량 거부 — 약 15분 관찰창 누계 138,841건, 9개 타입** (첨부 3 분포):
  - morai_msgs 8종(EgoVehicleStatus, ObjectStatusList, CollisionData 등) + **표준 `tf2_msgs/TFMessage`**.
  - 표준 tf가 포함된 점이 핵심입니다: ROS2 `std_msgs/Header`에는 `seq` 필드가 없으므로, **SIM이 ROS1 헤더 포맷으로 발행하는 한 어떤 morai_msgs를 소싱해도 해소되지 않는 구조**입니다.
- 역방향(`/ctrl_cmd`에 CtrlCmd 10Hz×5s 발행)도 차량 무반응이었습니다.

## 4. 실측 증거 (첨부 대응)
1. `avs007_t24_20260710_N2r1_launcher_environ.txt` — morai_msgs 소싱 반영 증거(AMENT_PREFIX_PATH)
2. `avs007_t24_20260710_N2r1_player.log` — Native 크래시 원본 로그(547행 std::bad_cast)
3. `avs007_t24_20260710_R2r1_rosbridge_sample.log` — 거부 유형 분포(누계 138,841건)·원문 샘플
4. `avs007_t24_20260710_R2r1_topics.txt` — 생성 토픽 23종 목록

## 5. 질문 / 요청
1. **내부 재현·확인하신 환경의 구체 정보**: host OS·ROS2 배포판/패치 버전, rosbridge_suite(또는 자체 브리지) 버전, morai_msgs 소싱 방법·버전. 저희 결과(위 3장)와의 차이를 특정하고자 합니다.
2. **Native**: 26.R1.H3 ros2cs(standalone=0, humble 2023-03-31 빌드)와 호환 검증된 host ROS2/Fast-DDS 정확한 버전 조합, 또는 **standalone ros2cs 빌드** 제공 가능 여부.
3. **rosbridge**: SIM이 ROS2 포맷(seq 없는 header)으로 발행하도록 하는 설정 유무, 혹은 검증에 사용하시는 rosbridge 버전/포크.

필요하시면 원격 재현 시연이 가능합니다.
