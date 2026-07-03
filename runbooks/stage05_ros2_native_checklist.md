# Stage 05 — MORAI ROS2 Native Topic 체크리스트

작업 정의: `runbooks/integrated_roadmap.md` 3장 표(Stage 05) — **"topic 확인 + sim/wall clock offset 측정"** (V7 준비).
선행: Stage 04 PASS(완료). 게이트 아님.

## 0. 연동 방식 (조사 결과, 2026-07-03)

MORAI SIM은 `RosBridgeClient.dll` 기반 — **rosbridge 방식**이다(순수 DDS 네이티브 아님).
SIM이 rosbridge_server(WebSocket 9090)에 **클라이언트로 접속**하고, 서버가 토픽을
실제 ROS2 DDS 토픽으로 노출한다 → `ros2 topic list` 에서 확인 가능.

- 메시지 정의: **`morai_ros2_msgs`** (github MORAI-Autonomous/MORAI-ROS2_morai_msgs, msg 32종).
  → `~/avstack/ros2_ws` 에 colcon 빌드 완료. 없으면 토픽은 떠도 타입 미해석.
- 참고: https://github.com/MORAI-Autonomous/MORAI-ROS2_morai_msgs ,
  MORAI ROS quick start (Edit→Network Settings→Bridge IP 설정).

## 1. 준비 (완료/사용자)

- [x] `morai_ros2_msgs` colcon 빌드: `~/avstack/ros2_ws/install` (32 msg 등록 확인)
- [x] 검증 스크립트: `scripts/stage05_ros2_native/{run_rosbridge,verify_topics}.sh`, `offset_probe.py`
- [ ] **(사용자/sudo)** rosbridge 설치: `sudo apt install -y ros-humble-rosbridge-suite`
- [ ] **(사용자)** MORAI SIM 기동: `scripts/run_morai_launcher_nvidia.sh` → 지도 로드

## 2. 실행 순서

1. **터미널 A** — rosbridge 서버:
   `bash scripts/stage05_ros2_native/run_rosbridge.sh`  (port 9090 대기)
2. **SIM** — Edit → Network Settings → **Bridge IP = 127.0.0.1**, port 9090 →
   ego/sensor publish 항목 활성화 → Apply. (Ego status, GPS, IMU 등 켬)
3. **터미널 B** — 검증:
   `bash scripts/stage05_ros2_native/verify_topics.sh`
   - `ros2 topic list` 에 MORAI 토픽(예: `/Ego_topic`, `/gps`, `/imu`, `/Object_topic`) 표시
   - `/Ego_topic` hz + `echo --once`
   - `offset_probe.py` 로 sim/wall offset(mean/median/stdev) 산출
   - offset 대상 토픽/타입이 다르면:
     `OFFSET_TOPIC=/gps OFFSET_TYPE=GPSMessage bash .../verify_topics.sh`

## 3. PASS / FAIL 판정

| # | 항목 | PASS 조건 |
|---|---|---|
| P1 | 연결 | rosbridge에 SIM 접속(`client_count`>0) |
| P2 | 토픽 노출 | `ros2 topic list` 에 MORAI 토픽 ≥1 (typed) |
| P3 | 수신 | `/Ego_topic` echo --once 성공, hz>0 |
| P4 | offset | `offset_probe.py` 가 n≥20 샘플로 mean/stdev 산출 |
| P5 | 기록 | stages.tsv 기록 + 증거 로그 |

**Stage 05 PASS** = P1·P2·P3·P4 성공 + P5. offset 수치는 05.7 재현성 캘리브레이션의 baseline.

**FAIL 시**: (a) 토픽 0 → SIM Network Settings publish 미활성/Bridge IP 오류/9090 포트 불일치,
(b) 타입 미해석 → `~/avstack/ros2_ws/install/setup.bash` 소싱 확인, (c) 이슈 등록(`record_issue.sh`).

## 4. 기록 위치

- 증거: `~/avstack/runs/stage05_verify_<ts>.log`, `stage05_morai_msgs_build_<ts>.log`
- Stage 기록: `scripts/record_stage.sh 05_ros2_native PASS "<요약>" "<로그>" "Stage 05.5"`
- offset 수치는 api_contract 계열이 아니라 stages 기록 요약 + 로그에 남긴다.

## 참고 — Docker 판단
- 로드맵 게이트: Docker 도입 판단은 Stage 05 통과 후, 실제 설치는 Stage 06 착수 시점(로드맵 3장).
