# Stage 04/05 — ROS2 Humble 셸 소싱 정책 (`rosenv`)

날짜: 2026-07-03. `~/.bashrc` 는 git 제외 대상이라 재현용으로 이 노트를 남긴다.
결론: **자동 소싱 대신 `rosenv` 함수(opt-in)** 를 쓰고, **MORAI SIM 은 런처가 ROS2 를 직접 소싱**한다.

## 배경 (정정 이력)
- SIM 내장 ros2cs 는 `standalone=0`(비자체포함, humble 타깃) → **SIM 은 ROS2 Humble 이 소싱돼야** 동작한다
  (core librcl 등을 host ROS2 에서 로드). 상세: `stage05_ros2_native_checklist.md` 함정 1.
- 따라서 SIM 실행 환경에는 ROS2 가 **있어야** 한다. 이는 런처(`run_morai_launcher_nvidia.sh`)가
  실행 전 `/opt/ros/humble/setup.bash` 를 소싱해 보장한다(SIM 프로세스가 상속).
- 그러므로 `.bashrc` 의 auto-source 여부는 **SIM 동작과 무관**하다(런처가 알아서 소싱). 그래서
  대화형 셸은 기본 ROS-free 로 두고 필요할 때만 `rosenv` 로 소싱하는 편이 깔끔해 이 방식을 택했다.
  (초기엔 auto-source 를 넣었다가 rosenv 로 교체. auto-source 로 돌려도 무해하나 불필요.)

## 현재 방식 (`~/.bashrc` 말미)
```bash
# --- ROS2 Humble (avstack Stage 04/05) ---
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
- **ROS2 리스너/명령 터미널**: `rosenv` 입력 후 `ros2 ...`. (Stage 05 스크립트는 `env.sh` 가 자동 처리.)
- **MORAI SIM**: 반드시 `scripts/run_morai_launcher_nvidia.sh` 로 실행(런처가 ROS2 소싱 포함). 이 래퍼
  안 거치고 SIM 을 직접 띄우면 ROS2 미소싱으로 Connect 실패 가능.
- RMW 는 **rmw_fastrtps_cpp**(기본). cyclonedds 로 바꾸지 말 것(SIM=fastrtps, 토픽 안 보임).

## 롤백
- `.bashrc` 의 `--- ROS2 Humble ... --- end ---` 블록 삭제.
