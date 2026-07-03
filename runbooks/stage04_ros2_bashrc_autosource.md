# Stage 04 보강 — ROS2 Humble .bashrc 자동 소싱

날짜: 2026-07-03. Stage 04(ROS2 Humble Host) PASS 후 편의 설정.
`~/.bashrc`는 git 제외 대상이므로 재현용으로 이 노트를 저장소에 남긴다.

## 배경
- 새 셸마다 `source /opt/ros/humble/setup.bash`를 수동 실행해야 `ros2`가 잡힘.
- 모든 로그인 셸에서 ROS 환경을 자동으로 붙이도록 `.bashrc`에 소싱 블록 추가.
- **주의**: `ROS_LOCALHOST_ONLY=1` 금지(CLAUDE.md) → 블록에서 `=0` 명시.

## 반영 내용 (`~/.bashrc` 말미에 append)
```bash
# --- ROS2 Humble (avstack Stage 04) ---
# 자동 소싱. ROS_LOCALHOST_ONLY=1 금지(CLAUDE.md 규칙) → 0 명시.
if [ -f /opt/ros/humble/setup.bash ]; then
  source /opt/ros/humble/setup.bash
  export ROS_LOCALHOST_ONLY=0
fi
# --- end ROS2 Humble ---
```

## 검증
```
$ bash -lic 'echo "$ROS_DISTRO $ROS_LOCALHOST_ONLY"; command -v ros2'
humble 0
/opt/ros/humble/bin/ros2
```

## 재현 (새 호스트/재설치 시)
1. Stage 04로 `ros-humble-desktop` 설치 완료 상태 전제.
2. 위 블록을 `~/.bashrc` 끝에 추가.
3. 새 터미널 또는 `source ~/.bashrc` 후 `ros2 doctor` 확인.

## 부작용 / 롤백
- 부작용: 모든 셸에 ROS 환경(PATH/AMENT 등)이 항상 붙음. ROS 미사용 작업에도 영향.
- 롤백: `.bashrc`의 `--- ROS2 Humble ... --- end ---` 블록 삭제.

증거: `~/avstack/runs/stage04_bashrc_autosource_20260703_144649.log`
