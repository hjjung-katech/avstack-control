# ROS2 Humble 설치 패킷 — WRX90 (Stage 04 상당)

> 랩탑 t15p Stage 04 PASS 구성(ros-humble-desktop, apt source `jammy main`, RMW=fastrtps)을 복제하되 **AVS-007 학습 반영**. 실행=사용자(sudo), 프리플라이트·검증=Claude(비-sudo).
> 근거: 랩탑 실측(2026-07-28) + `runbooks/t24_vendor_diag_verification.md`(AVS-007). 스테이징된 msgs: `~/avstack/ros2_ws_26r1/src/morai_ros2_msgs`(B, `c84d648`).

## 0. 프리플라이트 (Claude 확인 완료 — wrx90 2026-07-28)
- Ubuntu **22.04.5 jammy** ✓ (humble 타깃) · `LANG=en_US.UTF-8` ✓ · universe repo 활성 ✓ · `curl` ✓ · `/opt/ros` **clean**(미설치) ✓
- → locale/universe 조치 불필요. 아래 1번부터 진행.

## 1. ROS2 apt 저장소 (사용자 sudo) — 랩탑과 동일 소스
```bash
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list
sudo apt-get update
```

## 2. ROS2 Humble + 개발도구 설치 (사용자 sudo)
```bash
sudo apt-get install -y ros-humble-desktop
sudo apt-get install -y python3-colcon-common-extensions python3-rosdep python3-vcstool build-essential
```
- 랩탑 참조: `ros-humble-desktop` 0.10.0-1jammy (273 pkg). 버전은 롤링 패치라 소폭 다를 수 있음(desktop 메타패키지라 무방).

## 3. rosdep 초기화 (init=sudo, update=사용자)
```bash
sudo rosdep init          # 이미 있으면 "already exists" — 무시
rosdep update             # sudo 아님
```

## 4. 쉘 환경 (~/.bashrc, 사용자) — ⚠️ AVS-007 반영
```bash
cat >> ~/.bashrc <<'RC'
# --- ROS2 humble ---
source /opt/ros/humble/setup.bash
export ROS_LOCALHOST_ONLY=0      # CLAUDE.md: 1 금지
# RMW_IMPLEMENTATION 은 설정하지 않는다.
#  - humble 기본 RMW = rmw_fastrtps_cpp (명시 설정 없이도 fastrtps).
#  - AVS-007: RMW_IMPLEMENTATION 을 "설정"하는 것 자체가 MORAI SIM startup std::bad_cast 트리거.
#    미설정이면 rcl 의 rmw identifier 검사 경로가 열리지 않아 안전.
#  → 랩탑은 과거에 명시 설정 후 래퍼가 unset 했지만, wrx90은 처음부터 미설정을 기준선으로 한다.
RC
source ~/.bashrc
```
> SIM 실행은 항상 `scripts/run_morai_launcher_nvidia.sh`(SOURCE_ROS2=1 시 RMW 자동 unset 가드 포함)로만.

## 5. 검증 (Claude 비-sudo 가능 — 설치 후)
랩탑 Stage 04 PASS 기준과 동일:
```bash
# 터미널 A
source /opt/ros/humble/setup.bash && ros2 run demo_nodes_cpp talker
# 터미널 B (또는 Claude)
source /opt/ros/humble/setup.bash && timeout 5 ros2 topic echo /chatter --once
```
- 기대: `/chatter` 에서 "Hello World: N" 1건 수신. `ros2 doctor`·`ros2 pkg list | wc -l` 도 참고.
- 증거는 `~/avstack/runs/` 에 동결(Claude가 수행·기록).

## 6. 다음 (msgs 빌드 — 스테이징 산출물 연결)
`~/avstack/ros2_ws_26r1/src/`에 **두 패키지 스테이징 완료**(2026-07-28):
- `morai_ros2_msgs` — git `c84d648`(B). 패키지명 `morai_ros2_msgs`.
- `morai_msgs` — 랩탑 벤더본 Restore(non-git, rsync). 패키지명 `morai_msgs`. **EgoVehicleStatus 등 내용은 git본과 동일**(패키지명만 다른 동일 리포).

⚠️ **SIM이 발행하는 타입 네임스페이스 확정이 먼저**(morai_msgs vs morai_ros2_msgs). native 게이트에서:
```bash
# SIM ROS2 Connect 후:
ros2 topic type /ego_vehicle_status     # → 예: morai_msgs/msg/EgoVehicleStatus
```
- 관례상 MORAI SIM은 **`morai_msgs/msg/*`** 발행(랩탑 Stage05 PASS도 이 벤더본 사용). 확인된 네임스페이스와 **일치하는 패키지만** 빌드:
```bash
cd ~/avstack/ros2_ws_26r1
colcon build --packages-select morai_msgs      # 또는 확인 결과에 따라 morai_ros2_msgs
source install/setup.bash
ros2 interface show morai_msgs/msg/EgoVehicleStatus
```
- 이후 SIM ROS2 Connect → `/ego_vehicle_status` 50Hz 수신 + `CtrlCmd` 제어(AVS-007 native 레시피, RMW 미설정).

---
**요약 실행 순서**: (사용자 sudo) 1 저장소 → 2 설치 → 3 rosdep → 4 bashrc, (Claude) 5 검증 → 6 msgs 빌드.
설치 완료하시면 알려주세요 — Claude가 5번(talker/echo) 검증하고 증거 동결·Stage04상당 기록까지 처리합니다.
