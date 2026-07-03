# AVS-007 리포트 — MORAI 26.R1.H3 ROS2 Native(ros2cs) 연동 실패 분석 & 문의

작성 2026-07-03. 목적: (1) 지금까지 진단의 비판적 재검토, (2) MORAI 문의용 정리, (3) 다음 단계.

## 1. 환경 (사실)
- SIM: `Simulator_v.R1.260701.H3` (26.R1 H3, 2026-07-01 빌드)
- SIM ros2cs 메타데이터: `<ros2>humble</ros2>`, `<standalone>0</standalone>`, ros2cs `1.3.0`, 빌드일 `2023-03-31`
  (`.../Simulator_Data/Plugins/metadata_ros2cs.xml`, `metadata_ros2_for_unity.xml`)
- SIM Plugins: `rosidl_typesupport_fastrtps` 301+개 번들. **libfastrtps/libfastcdr/librmw/librcl 은 미번들** → host 의존.
- Host: Ubuntu 22.04, ROS2 **Humble desktop** (apt), `ros-humble-rmw-fastrtps-cpp 6.2.10-1jammy.20260605`,
  `libfastrtps.so.2.6.11`, `libfastcdr.so.1.0.29`. (Stage 04 talker/listener 정상 = host ROS2 자체는 건전)

## 2. 증상 (재현)
- **ROS2 미소싱(기본)**: SIM 정상 시작. Network Settings ROS2 **Connect 시** ros2cs 가 `librcl.so` 등을 못 찾음
  → `TypeInitializationException: ROS2.NativeRcl` → `Ros2Connect()` 실패, Disconnect 유지.
- **ROS2 소싱(`SOURCE_ROS2=1`)**: SIM 이 번들 typesupport 를 preload 후, host rmw 로드 단계에서
  `[rcl] failed to load 'librmw_fastrtps_cpp.so' due to std::bad_cast (functions.cpp:65), exiting with 1`
  → **SIM 이 startup 에서 즉시 종료**(Start 안 됨).
- 즉 host Humble 을 켜도(startup 사망) 꺼도(Connect 실패) 교착.

## 3. 비판적 재검토 — 정말 "버전 ABI" 문제인가?

**단단한 사실**
- 배포판은 humble 로 **정확히 일치**(잘못된 distro 설치 아님).
- host `librmw_fastrtps_cpp.so` 는 **단독 dlopen OK**, Stage 04 pub/sub 정상 → host ROS2 설치 건전.
- 실패는 **SIM 번들 typesupport(2023) + host fastrtps/rmw(2026) 혼용 시에만** 발생.

**불확실/추론 (정직하게)**
- Humble 은 **패치 간 ABI 안정**이 원칙이다. 그런데 2023 typesupport ↔ 2026 rmw 혼용이 `std::bad_cast` 를
  낸다는 건 이례적 → 원인이 아래 중 무엇인지 **아직 확정 못 함**:
  - (H1) eProsima Fast-DDS **패치 레벨 ABI/직렬화 비호환** (2.6 초반 ↔ 2.6.11).
  - (H2) **RTTI/dlopen 가시성** 문제(ros2cs/Unity 가 typesupport 를 RTLD_LOCAL 로 로드 → dynamic_cast 실패).
  - (H3) 내가 **매뉴얼의 지정 절차/버전을 안 따름**(예: MORAI 가 특정 Humble 패치·docker 를 지정).
- 참고: ros2/rmw_fastrtps #733/#797 은 **distro 혼용** 시 bad_alloc/bad_cast 보고(우리는 동일 distro, 패치만 상이).
- **결론**: "host ROS2 를 2023 버전으로 정합" 은 **H1 이면 유효**하나 **H2/H3 이면 효과 없을 수 있음**.

### 3-1. #2 실험 결과 (2026-07-03) — **H1 반증됨**
2023-03-13 스냅샷의 Fast-DDS 계열(2.6.4/rmw 6.2.2/typesupport 2.2.0)을 SIM 에만 앞세워 실행:
- SIM environ 캡처로 prefix 전파 확인(LD_LIBRARY_PATH 맨 앞). 그럼에도 **동일 `librmw_fastrtps_cpp
  std::bad_cast` 로 startup 사망**. 2026/2023 무관하게 같은 실패.
- 대조: 동일 2023 libs 를 얹은 rclpy 는 정상(실제 2023 lib 로드 확인). → 코드 경로 자체는 건전.
- **∴ 원인은 host ROS2 버전이 아님. SIM ros2cs/Unity 로딩 특유(H2/H3).**
  **host 다운그레이드/버전정합은 해결책이 아니다(실험적 확정).**

**내 진단 이력의 오류 (기록)**
- 중간에 "SIM 실행 셸에서 ROS2 를 격리해야 한다"고 정반대로 판단해 런처에 격리 로직을 넣었다가 되돌림.
  실제로는 standalone=0 이라 ROS2 가 **필요**. (혼선 사과. 최종 런처는 기본 미소싱+`SOURCE_ROS2=1` opt-in.)
- RMW 를 cyclonedds 로 바꿨던 것도 오류(SIM typesupport=fastrtps). 최종 fastrtps 로 고정.

## 4. MORAI 문의 포인트 (그대로 사용)
1. 26.R1.H3 SIM 의 ROS2 Native(ros2cs, standalone=0, humble, 2023-03-31 빌드)를 붙이려면
   **정확히 어떤 ROS2 Humble 패치/버전**이 필요한가? (host 최신 Humble=fastrtps 2.6.11 에서 `librmw_fastrtps_cpp
   std::bad_cast` 로 SIM 이 종료)
2. 지원되는 **정확한 Fast-DDS(fastrtps) 버전** 또는 **동봉/권장 apt 스냅샷·docker 이미지**가 있는가?
3. ros2cs 를 **standalone=1(자체포함) 빌드**로 제공할 수 있는가? (host 버전 의존 제거)
4. 공식 매뉴얼의 ROS2 Native 설치 절차(요구 버전·RMW·설정)를 알려달라. (help-morai-sim ROS2 페이지 링크 포함)

### 3-2. rosbridge 경로 실측 (2026-07-03) — 연결 OK, **데이터 포맷 불일치로 차단**
- Simulator/Ego/Sensor 를 ROS(bridge)/9090 으로 연결(client_count 32). `morai_msgs` ROS2 패키지
  빌드로 타입 해결 → rosbridge 가 /Ego_topic·/gps 등 대량 토픽 **생성(advertise)**.
- **그러나 데이터 0.** rosbridge 가 SIM publish 를 필드 불일치로 전부 거부. **정밀 원인(전체 로그)**:
  ```
  morai_msgs/EgoVehicleStatus does not have a field header.seq
  tf2_msgs/TFMessage        does not have a field transforms.header.seq
  ```
  누락 필드 = **`header.seq`** — ROS1 `std_msgs/Header` 의 `seq`(ROS2 에서 제거됨). MORAI ROS-bridge 가
  **ROS1 헤더(seq 포함)** 로 전송 → ROS2 rosbridge_suite(2.0.7) 가 미지 필드로 엄격 거부.
- **∴ 근본 포맷 불일치가 아니라 단일 `header.seq` 문제 → rosbridge 경로는 FIXABLE**(구버전 rosbridge
  관용 / message_conversion 이 unknown 필드 무시하도록 패치 / seq strip). native(ABI, AVS-007)와 달리
  rosbridge 는 우리 쪽 우회로 해결 가능성 높음(미시도).

## 5. 다음 단계 (양 경로 실측 후 갱신)
**핵심**: MORAI 26.R1.H3 ↔ host Humble/rosbridge_suite(둘 다 2026) 버전 불일치로 native·rosbridge 모두 차단.
근본 해결은 MORAI 지원 필요.
1. **[주 경로] MORAI 문의** — §4 + 다음 추가:
   - native: standalone ros2cs 빌드 또는 `librmw_fastrtps_cpp std::bad_cast` 회피 절차(버전정합은 반증 첨부).
   - rosbridge: SIM 이 기대하는 **rosbridge_suite 버전** 또는 26.R1.H3 에 정합하는 **morai_msgs/msg 정의 세트**.
   - 또는 26.R1.H3 검증된 **완전한 ROS2 연동 환경(권장 OS/ROS2 버전/docker)**.
2. **[탐색·선택] 호환 조합 실험(원하면)** — (a) 구버전 rosbridge_suite 로 관용 검증, (b) SIM 버전에 맞는
   morai_msgs 필드 정의로 재빌드(단 표준 tf 불일치는 잔존). 성공 불확실, 시간 소요.
3. **[보류] host ROS2 버전 정합** — #2 실험으로 무효(H1 반증). 재시도 불필요.

## 부록 — 증거 파일
- `~/avstack/logs/avs007_ros2cs_abi_mismatch_20260703.md` (원 증거: metadata/ldd/Player.log/버전)
- 커밋: `89853e1`(AVS-007 open + 런처 revert), `566224b`(소싱 시도), 관련 stage05 스캐폴드.
