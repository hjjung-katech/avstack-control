# AVS-001 — Scenario Runner 창 미표시 (RESOLVED)

Scenario Runner의 "Start Scenario Runner" 버튼은 활성인데 창이 뜨지 않던 문제.
재발 시 아래 체크리스트를 위에서부터 그대로 따른다.

- 상태: RESOLVED (2026-07-02, Stage 02)
- 관련 기록: `records/issues.tsv` AVS-001, `records/stages.tsv` 02_scenario_runner
- 관련 이슈: OPEN-05 (SR 단독 로그인은 계정 ID 필요), AVS-004 (SR GUI 검은 렌더 — 별개 문제)

## 1. 증상
- Launcher 로그인 성공, SIM은 정상 구동.
- Scenario Runner 실행 버튼은 눌리지만 **창이 나타나지 않음**.
- 터미널에도 뚜렷한 에러가 안 보임 (Launcher가 자식 프로세스 stderr를 삼킴).

## 2. 원인
- Scenario Runner(PyInstaller + PySide2/Qt 5.15)가 요구하는 **네이티브 라이브러리 누락**:
  - `libxcb-xinerama0` — Qt xcb 플랫폼 플러그인 로드 실패 → 창 생성 자체가 안 됨.
  - `liblapack3` / `libblas3` — numpy/과학 스택 의존, 미설치 시 조기 종료.
- Launcher가 자식 stderr를 삼켜 에러가 표면에 안 드러난 것이 오진을 유발.
- **배제된 가설**: "SIM의 OpenGL 컨텍스트 상속 문제" 아님 (SIM은 Vulkan+NVIDIA, SR과 무관).

## 3. 해결 절차 (재발 시 체크리스트)

### 3.1 라이브러리 확인
```bash
dpkg -l | grep -E "libxcb-xinerama0|liblapack3|libblas3"
```
- 세 개 모두 `ii`(설치됨)로 나오는지 확인. 하나라도 없으면 3.2로.

### 3.2 설치 (sudo — 사용자 확인 후 실행)
> CLAUDE.md 규칙: sudo 설치는 사용자 확인 후에만. 아래는 사용자가 직접 `! ` 프리픽스로 실행하거나 로컬 터미널에서 실행한다.
```bash
sudo apt install -y libxcb-xinerama0 liblapack3 libblas3
```

### 3.3 Qt 플랫폼 플러그인 원인 격리 (창이 여전히 안 뜰 때)
```bash
export QT_DEBUG_PLUGINS=1   # SR 실행 후 xcb 플러그인 로드 실패 메시지 확인
```
- "Could not load the Qt platform plugin xcb" 계열 메시지가 있으면 누락 lib가 더 있는지 `ldd`로 추적.

### 3.4 정상 경로로 SR 실행
- **SIM flow 경유로 연다** (Launcher → SIM → Scenario Runner). 원격은 `RUN_REMOTE=1`.
- 원격(NoMachine) 시 `DISPLAY=:1`, `XAUTHORITY=~/.Xauthority` 가 설정돼야 함 (run 스크립트가 처리).
- MORAI 계열은 반드시 `scripts/run_morai_launcher_nvidia.sh` 로만 실행.

## 4. 검증 (통과 기준)
- [ ] SR 메인 UI가 표시되고 강제 종료 없이 유지됨.
- [ ] 예제 xosc 로드 가능 (Stage 03: KATRI + `Scenario_Cut_In_1.xosc`).
- [ ] 근거 로그: `~/avstack/runs/stage02_sr_login_*.log` 에 로그인/UI 진입 흔적.

## 5. 주의 / 남은 제약
- **SR 단독 실행 로그인은 계정 ID가 필요**(OPEN-05). 그래서 SIM flow 경유가 기본 경로.
- 창은 떠도 **클라이언트 영역이 검게 렌더**될 수 있음 → 그건 이 이슈가 아니라 **AVS-004**(VTK/OpenGL GUI black). 블라인드 조작 + SIM에서 결과 확인으로 우회.
