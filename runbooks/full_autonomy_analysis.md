# MORAI 진단·파이프라인 완전 자율화 방안 분석

| 항목 | 내용 |
|---|---|
| 문서명 | 완전 자율화(무인 운영) 방안 조사·분석 |
| 버전 | v1.0 |
| 작성일 | 2026-07-04 |
| 위치 | `~/avstack-control/runbooks/full_autonomy_analysis.md` |
| 배경 이슈 | 원격 진단이 GUI 2관문에 차단됨 (런처 Start, Network Settings Connect) |
| 관련 | 설계노트 R3/R11(Headless), 성숙도 L6, AVS-007 |

---

## 1. 문제의 정확한 정의

"완전 자율"에는 층위가 두 개 있고, 섞으면 판단을 그르친다.

| 층위 | 정의 | 현재 차단 요인 |
|---|---|---|
| **자율-1** | 이번 AVS-007 진단(D1~D5)을 사람 개입 없이 완주 | GUI 2관문 |
| **자율-2** | 파이프라인 전체의 무인 운영 (야간/CI, 성숙도 L6) | GUI 2관문 + SIM Headless 미확정(R3) + 클라이언트 Qt(R11) |

**GUI 2관문의 성격 (실측 확정)**

1. **런처 → 지도 선택 + Start**: Simulator 자동기동 없음. 매 세션 클릭 필요.
2. **SIM → Network Settings → Connect**: ROS 네트워크 설정이 prefs에 **비저장**(gRPCPort만 저장). 파일로 심을 수 없어 매 세션 GUI 조작이 구조적으로 강제된다.

2번이 더 심각하다. 1번은 "실행"이지만 2번은 "상태 설정"이라, 설정 파일 우회라는 정석 해법이 벤더에 의해 막혀 있다.

---

## 2. 방법 후보 전수 분석

### 후보 매트릭스

| # | 방법 | 원리 | 성공 가능성 | 구축 비용 | 판정 |
|---|---|---|---|---|---|
| A | 좌표 재생 (record & replay) | 사람이 1회 시연 → 좌표·타이밍 기록 → xdotool 재생 | 중 | 낮음 | **채택 (1차)** |
| B | 시각 피드백 루프 | 스크린샷 → Claude가 이미지 판독 → 좌표 결정 → 클릭 | 중상 | 중 | **채택 (2차, A의 검증층)** |
| C | AT-SPI/dogtail 접근성 트리 | UI 요소를 이름으로 조작 | 매우 낮음 | 중 | **기각** — Unity 앱은 접근성 트리 미노출 |
| D | 설정 파일/CLI 인자 우회 | prefs·config에 값 주입, 실행 인자 | 낮음 | 낮음 | **부분 기각** — ROS 설정 비저장 실측 확정. 단 벤더 문의 항목으로 유지 |
| E | 아키텍처 우회 (GUI 의존 제거) | ROS2 Native 대신 API polling을 자동화 경로의 주 소스로 승격 | **높음** | 중 | **채택 (전략)** |
| F | ydotool/uinput 커널 레벨 입력 | X 우회 입력 주입 | 중 | 중 | 보류 — X11 세션이므로 xdotool로 충분, 이점 없음 |
| G | Unity -batchmode 등 헤드리스 인자 | 렌더링 생략 실행 | 낮음 | 낮음 | 기존 판단 유지 (R3) — 공식 근거 없음, 별도 R&D |

### 핵심 재평가: "화면을 볼 수 없다"는 제약은 절반이 도구 문제다

Claude Code는 **PNG 이미지를 직접 판독할 수 있다.** 현재 차단된 것은 시각 능력이 아니라 캡처 변환기 부재(xwd만 있고 PNG 변환기 없음)다. 즉:

```text
현재:  xwd 캡처 가능 → PNG 변환 불가 → Claude 판독 불가 → 블라인드 클릭만 가능 → "비추천" 타당
설치 후: scrot/ImageMagick → PNG → Claude 판독 → 좌표 결정/검증 → 사실상 computer-use 에이전트
```

**1회 설치(사용자 sudo 필요, ~1분)로 B가 열린다:**

```bash
sudo apt install -y xdotool wmctrl scrot imagemagick x11-utils
```

이 설치는 Claude Code 권한상 deny(apt)이므로 사용자가 직접 1회 수행한다. 이후 Claude Code allowlist에 `Bash(xdotool *)`, `Bash(scrot *)`, `Bash(wmctrl *)` 추가를 검토한다(클릭 실행은 아래 5장의 안전 규칙 하에).

### E(아키텍처 우회)가 전략적으로 가장 확실한 이유

GUI 자동화(A/B)는 어떤 방식이든 **취약성이 내재**한다: 창 위치, 해상도, 다이얼로그 변형, 벤더 업데이트 시 UI 변경. 반면 Network Settings Connect가 필요한 유일한 이유는 **ROS2 Native 데이터 경로** 때문이다. 설계노트 9.4의 3원 소스에서 역할을 재배정하면:

```text
현행 설계: eventlog/statelog(정본) + rosbag(고주파) + API polling(fallback)
자율화 설계: eventlog/statelog(정본) + API polling(무인 자동화 주 경로) + rosbag(유인 세션 한정)
```

- eventlog/statelog는 GUI Connect 없이도 생성된다 (Scenario Runner 자체 산출물).
- API polling(gRPC)은 ROS와 무관하다 — Connect 불필요.
- Metric 정본이 이미 Runner 지표(Decision 5)이므로, **무인 회귀시험의 필수 데이터는 ROS 없이 전부 확보 가능**하다.
- 잃는 것: 고주파 동역학 상세(rosbag). 이는 "야간 무인 회귀는 Runner 지표 기반, 정밀 분석은 유인 세션에서 rosbag"으로 이원화하면 된다.

**결론: 자율-2(L6)의 크리티컬 패스에서 ROS2 Native를 제거하는 것이 GUI 자동화보다 근본적 해법이다.** 단, 이번 진단(자율-1)과 Autoware(Stage 06+)에는 ROS가 필요하므로 A/B도 병행 가치가 있다.

---

## 3. 채택안 상세 설계

### 3.1 A안: 좌표 재생 (1차, 오늘 구축 가능)

**원리**: GUI 시퀀스가 매 세션 동일하므로, 1회 사람 시연을 기록해 재생한다.

**재현성 확보 조건 (필수)**

```bash
# 1. 디스플레이 해상도 고정 (NoMachine 리사이즈로 좌표가 틀어지는 것 방지)
xrandr --output $(xrandr | grep " connected" | cut -d' ' -f1) --mode 1920x1080

# 2. 대상 창 위치·크기 강제 고정 (재생 전 매번)
wmctrl -r "MORAI" -e 0,100,100,1280,800
```

**기록 절차 (사람 1회, ~5분)**

```bash
# 시연자가 각 클릭 직전에 Enter를 누르면 현재 마우스 좌표를 기록하는 방식
# scripts/gui_autopilot/record_coords.sh 가 좌표 시퀀스를 coords_launcher.tsv / coords_netsettings.tsv 로 저장
step  x     y     action        label
1     640   420   click         map_select_kcity
2     880   640   click         btn_start
...
```

**재생 절차 (무인)**

```bash
# 각 스텝: 클릭 → 0.5~2s 대기 → 스크린샷 → 다음 스텝
xdotool mousemove $X $Y click 1
scrot /tmp/step_${N}.png
```

**한계**: 팝업 순서 변형, 로딩 시간 변동에 취약 → B를 검증층으로 결합.

### 3.2 B안: 시각 피드백 루프 (2차, A의 신뢰성 보강)

**원리**: 각 스텝 후 스크린샷을 Claude Code가 판독하여 "기대 화면인가"를 확인하고 진행/재시도/중단을 결정한다.

```text
[재생 스텝 N] → scrot → Claude 판독:
  기대 상태 일치 → 스텝 N+1
  로딩 중       → 2s 대기 후 재캡처 (최대 5회)
  예상 외 화면  → 중단 + 스크린샷 보존 + 사람 호출
```

이 구조에서 A의 좌표는 "1차 추정"이 되고, B가 오류를 흡수한다. 벤더 UI가 소폭 바뀌어도 Claude가 스크린샷에서 버튼을 재식별해 좌표를 갱신할 수 있다.

**타이밍 원칙**: `sleep N` 고정 대기 금지. 항상 "스크린샷 → 상태 확인" 루프로 대기한다 (지도 로딩은 세션마다 10~60s 변동).

### 3.3 E안: 무인 파이프라인의 데이터 경로 재설계 (전략)

- ADR 제안: "무인 회귀시험(L6 경로)의 데이터 소스는 Runner 산출물 + API polling으로 한정하고, rosbag은 유인 세션 산출물로 분류한다."
- 설계노트 반영: 9.4 표에 '무인/유인' 컬럼 추가, 성숙도 L6 정의에서 ROS2 Native를 전제 조건에서 제외.
- 효과: **Network Settings Connect가 무인 크리티컬 패스에서 사라진다.** GUI 자동화는 "런처 Start" 1관문만 담당하면 된다 (난도 대폭 하락 — 다이얼로그 15+단계가 아니라 클릭 2~3회).

---

## 4. 통합 로드맵 (자율화 트랙)

| 시점 | 작업 | 산출물 | 층위 |
|---|---|---|---|
| **오늘** | 진단은 A안(사람 1분 세팅) 또는 C(보류)로 처리 — GUI 자동화 구축을 진단 완주와 묶지 않는다 | AVS-007 귀속 | 자율-1 |
| 오늘 | 도구 1회 설치 (xdotool 등 5종, 사용자 sudo) | — | 준비 |
| +1~2일 | **PoC-1**: 런처 시퀀스(지도+Start)만 좌표 재생 + 시각 검증 | gui_autopilot/launcher_start.sh | 자율-1/2 |
| +1~2일 | **PoC-2**: Network Settings 시퀀스 기록·재생 | gui_autopilot/ros_connect.sh | 자율-1 |
| PoC 후 | 무인 재현성 게이트: **3회 연속 성공** 시 자동화 채택, 실패 시 해당 관문은 유인 유지 | 판정 기록 | 게이트 |
| 병행 | MORAI 문의에 기능 요청 추가: ① CLI/설정파일 기반 ROS 연결 ② 시나리오 시작 시 자동 Connect 옵션 ③ 런처 자동기동 인자 | 문의 보강 | 자율-2 |
| 병행 | E안 ADR + 설계노트 개정 (L6에서 ROS Native 제외) | ADR, erratum | 자율-2 |
| 중기 | 무인 야간 회귀 리허설: 부팅 후 자동 로그인 세션 → launcher_start → API 기반 suite → 기록 | L6 리허설 보고 | 자율-2 |

**의사결정 원칙**: GUI 자동화는 "3회 연속 무인 재현" 게이트를 통과한 시퀀스만 신뢰한다. 통과 못 한 관문에 시간을 계속 붓지 말고, 그 관문은 유인으로 확정하고 E안으로 크리티컬 패스에서 빼는 쪽이 낫다.

---

## 5. 안전·보안 경계 (GUI 자동화의 금지선)

| 규칙 | 이유 |
|---|---|
| **라이선스/로그인 화면 감지 시 즉시 중단, 자격증명 입력 자동화 금지** | 계정·라이선스 보호 (운영가이드 21장). 로그인은 런처가 세션을 기억하는지 먼저 확인하고, 기억 못 하면 로그인만 유인 스텝으로 분리 |
| 클릭 대상은 기록된 좌표 시퀀스와 Claude가 스크린샷에서 식별한 요소로 한정. 임의 탐색 클릭 금지 | 예기치 않은 설정 변경 방지 |
| 각 스텝 스크린샷을 `~/avstack/logs/gui_autopilot/`에 보존 | 사후 감사 가능성 (무엇을 클릭했는지 증거) |
| MORAI 바이너리·설치 파일 불변 원칙 유지 | 기존 규칙 |
| 예상 외 화면 2회 연속 시 전체 중단 + 사람 호출 | 폭주 방지 |

---

## 6. Claude Code 투입 프롬프트 (PoC 스캐폴딩)

> 사전: 사용자가 `sudo apt install -y xdotool wmctrl scrot imagemagick x11-utils` 1회 실행 완료 후 투입.

```text
runbooks/full_autonomy_analysis.md 를 읽고 GUI 자동화 PoC를 스캐폴딩한다.
이번 작업은 스크립트 준비와 기록 도구까지다. 실제 클릭 재생은 좌표 기록이
완료된 후 내 승인 하에 실행한다.

작업:
1. scripts/gui_autopilot/ 에 다음을 작성해라:
   - preflight_display.sh: DISPLAY 확인, xrandr로 현재 해상도 출력,
     xdotool/wmctrl/scrot 설치 확인, MORAI 창 존재 시 wmctrl 목록 출력
   - record_coords.sh: 시연 기록기. 안내 문구 출력 후, 사용자가 Enter를
     누를 때마다 xdotool getmouselocation 좌표와 라벨(프롬프트로 입력받음)을
     TSV(coords_<시퀀스명>.tsv)에 append. 종료는 'q'.
   - replay_coords.sh: TSV를 읽어 스텝별로 wmctrl 창 위치 고정 →
     xdotool 클릭 → scrot 캡처(~/avstack/logs/gui_autopilot/<시퀀스>_step<N>.png)
     → 다음 스텝. --dry-run 옵션(클릭 없이 좌표·캡처만) 필수 구현.
   - verify_step.md: 시퀀스별 각 스텝의 기대 화면 설명 템플릿
     (내가 스크린샷을 너에게 보여주며 판정할 때 사용할 체크리스트)
2. 안전 규칙을 replay_coords.sh에 하드코딩해라:
   - 시작 전 스크린샷 1장을 찍고, 화면에 "login/license/password" 류
     텍스트 창이 의심되면(창 제목 기준 wmctrl 검사) 실행 거부
   - 스텝 간 기본 대기 1.5s, --step 옵션으로 한 스텝씩 수동 진행 가능
3. runbooks/gui_autopilot_runbook.md 작성: 해상도 고정 → 창 고정 → 기록 →
   dry-run → 시각 검증 → 실재생 → 3회 재현 게이트, 순서대로.
4. 커밋: "autonomy: scaffold gui autopilot PoC (record/replay + visual verify)"

제약:
- sudo, apt를 스크립트에 넣지 마라 (설치는 사용자 담당).
- 자격증명 입력을 자동화하는 코드를 어떤 형태로도 작성하지 마라.
- 실제 replay(클릭)는 이 세션에서 실행하지 마라. dry-run까지만 허용.
```

---

## 7. 요약 판단

1. **오늘의 진단**은 GUI 자동화 구축과 분리한다 — 사람 1분(A) 또는 보류(C)가 합리적이며, Claude Code의 판단은 타당했다.
2. **자율-1(진단 완주)**: 도구 5종 설치 + 좌표 재생 + 시각 검증 루프로 달성 가능성이 충분하다. "화면을 못 본다"는 제약은 PNG 변환기 부재였을 뿐이며, Claude Code의 이미지 판독 능력이 미사용 자산이었다.
3. **자율-2(무인 파이프라인, L6)**: GUI 자동화만으로 쌓으면 취약하다. **ROS2 Native를 무인 크리티컬 패스에서 제외하는 아키텍처 재설계(E안)가 근본 해법**이며, GUI 자동화는 "런처 Start" 최소 관문만 담당시킨다.
4. 벤더 문의에 CLI/자동 Connect 기능 요청을 추가한다 — 장기적으로 가장 깨끗한 길은 벤더가 여는 것이다.