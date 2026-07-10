# MORAI 재회신 — 26.R1.H3 ROS2 연동 진단 검증 결과 (내부 ID: MORAI-001 후속 / 관련: AVS-007, T-24)

<!-- INTERNAL: 2026-07-08 양종범님 회신("morai_msgs 미소싱, 환경 설정 확인 권장")에 대한 검증 결과 재회신.
     스레드: Re: [과제협조] ... (Ref KATECH-SIM-ROS2). SENT 동결 시 INTERNAL 블록 제거.
     T-24 판정: 분기 C — 소싱 완료 상태에서 동일 증상. 근거: runbooks/t24_vendor_diag_verification.md §3-4. -->

안녕하세요 양종범님,

한국자동차연구원 정호정입니다. 회신 감사합니다.

권장해 주신 대로 **ROS2용 morai_msgs 소싱 상태를 재구성해 두 경로를 재시험**했으며,
아쉽게도 **소싱이 완료된 환경에서도 동일 증상이 재현**되어 결과와 증거를 공유드립니다.

## 1. 검증 환경 (권장사항 반영)

- 공식 리포 `MORAI-Autonomous/MORAI-ROS2_morai_msgs`를 SIM 버전과 정합한 **태그 `26.R1`(c84d648)로 빌드**
  (colcon, ROS2 Humble) 후 오버레이 소싱. `ros2 interface list` 기준 morai 인터페이스 0건 → 76건 확인.
- 소싱이 SIM 프로세스에 실제 반영됐음을 **SIM 부모 프로세스의 `/proc/<pid>/environ` 캡처로 확인**
  (첨부 1: `AMENT_PREFIX_PATH`에 morai_msgs 오버레이 포함).

## 2. 결과 — 소싱 후에도 동일 (2026-07-10 실측)

**A. ROS2 Native**: morai_msgs 소싱 상태에서 SIM Start 시 기존과 동일하게 startup에서 즉시 종료.
```
[rcl]: Error getting RMW implementation identifier ... 'failed to load shared library
'librmw_fastrtps_cpp.so' due to std::bad_cast, at ./src/functions.cpp:65', exiting with 1
```
(첨부 2 Player.log 547행. 크래시 지점이 **rcl/rmw 초기화 계층**으로, 메시지 패키지 소싱 이전 단계입니다.
종료까지 SIM은 RTPS(UDP 74xx) 미바인딩 = DDS participant 미생성.)

**B. rosbridge**: 26.R1 정합 morai_msgs 소싱 상태에서 연결(client 33)·토픽 23종 생성은 정상이나
수신 데이터 0건. rosbridge_server가 SIM 발행을 **`header.seq` 필드 불일치로 전량 거부(관찰창 15분간 53,686건)**.
거부 9개 타입에 **표준 `tf2_msgs/TFMessage`가 포함**되어 있어 morai_msgs 패키지 유무·버전과 무관합니다
(ROS2 `std_msgs/Header`에는 `seq` 필드가 없으므로, SIM이 ROS1 헤더 포맷으로 발행하는 한 어떤 msgs를
소싱해도 해소되지 않는 구조입니다). 역방향(`/ctrl_cmd` CtrlCmd 10Hz 발행)도 차량 무반응이었습니다.
(첨부 3: 거부 유형 분포·원문 로그 샘플, 첨부 4: 생성 토픽 목록)

## 3. 요청드리는 사항

1. **내부 재현·확인하신 환경의 구체 정보**를 공유 부탁드립니다: host ROS2 배포판·패치 버전,
   rosbridge_suite(또는 자체 브리지) 버전, morai_msgs 소싱 방법 — 저희 결과와의 차이를 특정하고자 합니다.
2. **Native**: 26.R1.H3 ros2cs(standalone=0, humble 2023-03-31 빌드)와 호환 검증된 host ROS2/Fast-DDS
   정확한 버전 조합, 또는 standalone ros2cs 빌드 제공이 가능한지요.
3. **rosbridge**: SIM이 ROS2 포맷(seq 없는 header)으로 발행하도록 하는 설정이 있는지, 혹은 검증에
   사용하시는 rosbridge 버전/포크가 별도로 있는지요.

첨부 (4건):
1. `avs007_t24_20260710_N2r1_launcher_environ.txt` — 소싱 반영 증거
2. `avs007_t24_20260710_N2r1_player.log` — Native 크래시 원본 로그
3. `avs007_t24_20260710_R2r1_rosbridge_sample.log` — rosbridge 거부 분포·샘플
4. `avs007_t24_20260710_R2r1_topics.txt` — 생성 토픽 목록

확인 부탁드리며, 필요하시면 원격 재현 시연도 가능합니다.

감사합니다.
정호정 드림
