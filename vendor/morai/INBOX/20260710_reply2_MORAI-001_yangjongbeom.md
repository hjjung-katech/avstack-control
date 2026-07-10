# MORAI 2차 회신 — 2026-07-10 (MORAI-001 T-24 재회신에 대한 답신)

| 항목 | 내용 |
|---|---|
| 수신일 | 2026-07-10 |
| 발신 | 양종범 (MORAI) |
| 스레드 | Re Re [과제협조] MORAI SIM 시나리오 검증 이슈 2건 — 한자연(Ref KATECH-API-PY37 / KATECH-SIM-ROS2) |
| 원본 | 사용자 보관 .eml (OneDrive) — **첨부: OpenSCENARIO API Python 3.13 재빌드 파일** |
| 대상 | MORAI-001(AVS-007) 질문 3건 답변 + MORAI-002(AVS-006) 재빌드 납품 |

## 본문 (전문)

> 안녕하세요, 정호정 책임연구원님.
> 모라이 양종범입니다.
>
> 먼저 문의주신 항목에 대해 답변드립니다.
>
> 1. 내부에서 재현·확인하셨을 때의 환경 정보 (Host ROS2 버전, rosbridge 버전, morai_msgs 소싱 방법)
>
> OS 정보
>
> ```
> lsb_release -a
> No LSB modules are available.
> Distributor ID: Ubuntu
> Description: Ubuntu 22.04.5 LTS
> Release: 22.04
> Codename: jammy
> ```
>
> morai_msgs 소싱 방법
>
> ```
> mkdir -p ~/morai_ws/src
> cd ~/morai_ws/src
> git clone https://github.com/MORAI-Autonomous/MORAI-ROS2_morai_msgs.git
> cd ..
> colcon build
> source install/setup.bash
> ```
>
> 2. Native 경로의 호환 검증된 Host ROS2/Fast-DDS 버전 조합 또는 Standalone ros2cs 빌드 제공 가능 여부
>
> Fast-DDS 관련 패키지 정보는 아래와 같습니다.
>
> ```
> dpkg -l | grep fastrtps
> ii  ros-humble-fastrtps 2.6.10-1jammy.20250718.233605
> ii  ros-humble-fastrtps-cmake-module  2.2.2-2jammy.20250718.232819
> ii  ros-humble-rmw-fastrtps-cpp  6.2.8-1jammy.20250719.012320
> ii  ros-humble-rmw-fastrtps-shared-cpp  6.2.8-1jammy.20250719.002545
> ii  ros-humble-rosidl-typesupport-fastrtps-c  2.2.2-2jammy.20250719.001032
> ii  ros-humble-rosidl-typesupport-fastrtps-cpp  2.2.2-2jammy.20250719.000836
> ```
>
> 또한 Standalone ros2cs 관련 Plugin은 Unity Project의 Plugins 폴더에 포함되어 있습니다.
>
> 3. rosbridge 경로에서 SIM이 ROS2 헤더 포맷(seq 없음)으로 발행하는 설정이 있는지 여부
>
> MORAI SIM에서는 ROS2 Topic의 Publish/Subscribe를 위해 rosbridge를 사용하고 있지 않아 해당 부분에 대해서는 정확한 답변을 드리기 어려운 점 양해 부탁드립니다.
>
> 또한 MORAI Launcher를 어떤 방식으로 실행하고 계신지 확인 부탁드립니다.
>
> 제가 동일 현상을 재현했을 당시에는 Terminal에서 ROS2 및 morai_msgs가 포함된 Workspace를 먼저 Source한 뒤 MORAI Launcher를 실행하였습니다.
>
> ```
> cd ~/Desktop/MoraiLauncher_Lin
> source /opt/ros/humble/setup.bash
> source ~/morai_ws/install/setup.bash
> ./MoraiLauncher_Lin.x86_64
> ```
>
> 번거로우시겠지만 위와 동일한 방법으로 실행했을 때도 SIM이 Startup 과정에서 동일하게 종료되는지 다시 한번 확인 부탁드립니다.
>
> 추가로 OpenSCENARIO API Python Upgrade 버전 빌드 파일 첨부파일로 송부드립니다.
>
> - Target Python Version: 3.13
>
> 감사합니다.
> 양종범 드림

## 요지 정리 (내부, 사실/추론 분리)

**(사실) 답변 내용**
1. 벤더 환경: Ubuntu 22.04.5 jammy(우리와 동일). morai_msgs는 **main 브랜치 클론**(태그 미지정) — 우리 T-24는 26.R1 태그 사용.
2. 벤더 Fast-DDS: **fastrtps 2.6.10 / rmw-fastrtps-cpp 6.2.8 (2025-07 sync)** ↔ 우리 2.6.11 / 6.2.10 (2026-06 sync). **호환 조합에 대한 직답 대신 자기 환경 버전 제공**. standalone ros2cs는 "Unity Project Plugins 폴더에 포함"이라고만 답변(별도 제공 없음).
3. **rosbridge는 MORAI의 ROS2 경로가 아님** — "ROS2 Topic Pub/Sub에 rosbridge를 사용하지 않음". → SIM Network "ROS" 모드의 header.seq(ROS1 포맷)가 설명됨: 그 모드는 ROS1용.
4. 재확인 요청: **터미널에서 소싱 후 런처 바이너리 직접 실행**(`./MoraiLauncher_Lin.x86_64`, 래퍼/MORAISim.sh 미경유) 방식으로 startup 종료 재현 여부.
5. **AVS-006: Python 3.13 대상 재빌드 API 첨부 송부** (약속 기한 준수).

**(추론) 시사점**
- 우리 실측과의 잔여 차이 후보: ① Fast-DDS/rmw 패치 버전(2025-07 vs 2026-06 — H1 반증 실험은 2023 조합이었으므로 **2025-07 조합은 미실측 셀**), ② 실행 방식(바이너리 직접 vs MORAISim.sh/래퍼), ③ morai_msgs main vs 26.R1(native 크래시가 rcl 계층이므로 관련성 낮음 추정).
- rosbridge 경로는 공식 지원 아님 → Stage 05는 native 경로로 수렴, rosbridge는 비공식 우회로 격하.
- "동일 현상을 재현했을 당시"가 (크래시 재현인지 / 소싱 후 정상 동작 확인인지) 문면상 모호 — 재확인 결과와 함께 명확화 필요.
