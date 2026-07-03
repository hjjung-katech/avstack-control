# Stage 04/05 — ROS2 Humble 셸 소싱 정책 (`rosenv`)

날짜: 2026-07-03. Stage 04 후 편의 설정으로 `.bashrc` 자동 소싱을 넣었다가,
Stage 05 에서 **MORAI SIM Connect 실패의 원인**임이 드러나 **수동 함수(`rosenv`) 방식으로 교체**.
`~/.bashrc` 는 git 제외 대상이므로 재현용으로 이 노트를 저장소에 남긴다.

## 왜 auto-source 를 버렸나 (중요)
- MORAI Launcher 는 Simulator 를 **`~/.bashrc` 를 읽는 셸로 spawn** 한다.
- `.bashrc` 가 ROS2 를 auto-source 하면 SIM 프로세스 환경에 `/opt/ros/humble` 이 유입되고,
  SIM 내장 ros2cs(FastDDS)가 이와 충돌해 **Network Settings Connect 가 실패**한다.
  (Player.log: `ROS2 version in 'ros2cs' metadata doesn't match currently sourced version`
   → `TypeInitializationException: ROS2.NativeRcl` → `Ros2Connect()`.)
- 검증: launcher `/proc/<pid>/environ` 은 ROS 0개인데, 그 자식 Simulator environ 에는
  `AMENT_PREFIX_PATH=/opt/ros/humble`, `ROS_DISTRO=humble` 존재 → **launcher 의 SIM-spawn 이 .bashrc 재소싱**.
- 그래서 auto-source 를 제거하면 기본 셸이 ROS-free 가 되고 launcher 의 SIM-spawn 도 clean 해진다.
  (`env -i bash -lic` 로 재현: 제거 후 `AMENT=none` 확인.)

## 현재 방식 (`~/.bashrc` 말미)
```bash
# --- ROS2 Humble (avstack Stage 04/05) ---
# ⚠️ 자동 소싱 금지 (MORAI SIM Connect 충돌). 필요할 때만 rosenv 로 수동 소싱.
rosenv() {
  source /opt/ros/humble/setup.bash
  [ -f "$HOME/avstack/ros2_ws/install/setup.bash" ] && source "$HOME/avstack/ros2_ws/install/setup.bash"
  export RMW_IMPLEMENTATION=rmw_fastrtps_cpp   # SIM 내장 ros2cs 와 동일 벤더(FastDDS)
  export ROS_LOCALHOST_ONLY=0                  # CLAUDE.md: 1 금지
  echo "[rosenv] ROS2 humble sourced (RMW=$RMW_IMPLEMENTATION)"
}
# --- end ROS2 Humble ---
```

## 사용 규칙
- **ROS2 작업 터미널**: `rosenv` 입력 후 `ros2 ...` 사용. (또는 Stage 05 스크립트는 `env.sh` 가 자동 처리.)
- **MORAI SIM 실행 터미널**: `rosenv` 를 부르지 말 것. 설령 불렀어도 래퍼
  (`scripts/run_morai_launcher_nvidia.sh`)가 실행 전 ROS 환경을 subshell 한정 제거하므로 안전.
- RMW 는 SIM(fastrtps)에 맞춰 **rmw_fastrtps_cpp**(기본). cyclonedds 로 바꾸지 말 것(토픽 안 보임).

## 롤백
- `.bashrc` 의 `--- ROS2 Humble ... --- end ---` 블록 삭제. (auto-source 로 되돌리지 말 것 — 함정 1 재발.)

상세 근거: `runbooks/stage05_ros2_native_checklist.md` 함정 1.
