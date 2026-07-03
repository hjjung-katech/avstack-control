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
- **결론**: "host ROS2 를 2023 버전으로 정합" 은 **H1 이면 유효**하나 **H2/H3 이면 효과 없을 수 있음** →
  다운그레이드를 강행하기 전에 **MORAI 의 공식 지정 환경 확인이 선행**돼야 한다.

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

## 5. 다음 단계 (권장 순서)
1. **[선행] MORAI 문의 발송** — 위 4개 질문. 다운그레이드 방향의 타깃 버전을 확정하기 위함.
   (동시에 help-morai-sim 26.R1 ROS2 문서에서 지정 버전 재확인.)
2. **[병행·저위험] rosbridge 경로 임시 검증** — SIM WebSocket 은 ros2cs/DDS ABI 를 안 타므로 이 블로커와 무관.
   host `rosbridge_server` + SIM ROS(bridge) Connect 로 토픽/‑offset 을 먼저 확보(Stage 05 진행 유지).
3. **[문의 회신 후] host ROS2 버전 정합** — MORAI 지정 버전으로 (a) 구 deb 핀 설치 또는 (b) 별도 prefix +
   `SOURCE_ROS2=1` + LD_LIBRARY_PATH 로 SIM 에만 적용(시스템 Humble 은 보존, 저위험 우선).
   - H2(RTTI) 가능성 대비: 버전 정합으로도 안 되면 ros2cs standalone 빌드/문의 회신에 의존.

## 부록 — 증거 파일
- `~/avstack/logs/avs007_ros2cs_abi_mismatch_20260703.md` (원 증거: metadata/ldd/Player.log/버전)
- 커밋: `89853e1`(AVS-007 open + 런처 revert), `566224b`(소싱 시도), 관련 stage05 스캐폴드.
