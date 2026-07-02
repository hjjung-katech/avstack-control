# AVStack 환경 설정 및 단계별 운영 가이드

**목적:** MORAI SIM + Scenario Runner + ROS2 Humble + Autoware 연동 환경을 Ubuntu에서 재현 가능하게 구축하고, 단계별 검증·이슈·로그·결정사항을 체계적으로 관리한다.
**대상 머신:** `t15p-dev-ubt`
**기준 OS:** Ubuntu 22.04.5 LTS
**문서 버전:** v1.3 (2026-07-02 개정)
**현재 상태:** Stage 00 PASS / git init·CLAUDE.md 확정본·MORAI 파일 배치 완료 / 첫 커밋 대기

## 개정 이력

| 버전 | 일자 | 내용 |
|---|---|---|
| v1.0 | 2026-07-02 | 최초 작성 |
| v1.1 | 2026-07-02 | settings.json 최종본, .gitignore 스코프 축소, sandbox 항목, additionalDirectories, CLAUDE.md 확정본, record_decision.sh, 진행 현황·Open Items 신설 |
| v1.2 | 2026-07-02 | (1) MORAI 실제 경로 반영: `~/avstack/morai/launcher/MoraiLauncher_lin.x86_64` (OPEN-01 해소) (2) Stage 00 증거 파일 실존 확인 (OPEN-02 해소) (3) CLAUDE.md 확정본 배치 확인 (OPEN-07 해소) (4) 3계층 기록 모델 명시 (5) 커밋 컨벤션 확정 (6) 문서 위치·활용 규칙 신설 (27장) |
| v1.3 | 2026-07-02 | (1) 브랜치 정책 신설: main 단일 브랜치(trunk-based), 예외 2종 (8.5) (2) Git 원격 저장소 확정: private GitHub `hjjung-katech`, SSH (OPEN-04 해소) |

---

## 0. 진행 현황 (이 섹션이 작업 재개 기준점이다)

### 0.1 완료된 것 (2026-07-02 기준)

| 항목 | 상태 | 비고 |
|---|---|---|
| Stage 00 Remote GPU 검증 | 완료 (PASS) | 증거: `~/avstack/logs/glxinfo_nvidia_prime.txt` (실존 확인) |
| git 설치 + identity | 완료 | Hojung Jung / hjjung2@katech.re.kr |
| `~/avstack-control` git init | 완료 | 첫 커밋 대기 |
| CLAUDE.md 확정본 생성 | 완료 | 19.1 확정본과 동일 |
| MORAI Launcher 파일 배치 | 완료 | `~/avstack/morai/launcher/MoraiLauncher_lin.x86_64` (압축 해제) |

### 0.2 미완료 (다음 작업 순서 — 이 순서대로 진행한다)

| 순서 | 작업 | 절차 위치 |
|---:|---|---|
| 1 | `records/*.tsv` 4종 생성 + 초기 기록 시딩 | 6장 |
| 2 | `scripts/` 스크립트 5종 생성 (MORAI 경로 v1.2 반영본) | 10.2, 20장 |
| 3 | `.claude/settings.json` + `settings.local.json` 생성 | 19.2 |
| 4 | `env/ros2_humble.env`, `.gitignore` 생성 | 13.1, 8.2 |
| 5 | 이 가이드를 `runbooks/operations_guide.md`로 배치 | 27장 |
| 6 | **첫 커밋 (baseline)** | 8.3 |
| 7 | Claude Code 설치 + 첫 세션 검증 + ADR-005 기록 | 18장 |
| 8 | Stage 01 실행 (MORAI Launcher/SIM) | 10장 |
| 9 | Stage 02 / AVS-001 진단 | 11장 |

1~4는 `bootstrap_avstack_control.sh`(v1.2: MORAI 경로 반영, CLAUDE.md 미덮어쓰기)를 실행하면 한 번에 처리된다. 멱등이며 기존 CLAUDE.md와 TSV를 보존한다.

### 0.3 Open Items

| ID | 항목 | 상태 | 내용 |
|---|---|---|---|
| OPEN-01 | MORAI 설치 경로 | **해소** | `~/avstack/morai/launcher/MoraiLauncher_lin.x86_64`로 확정. 스크립트 기본값 반영 완료 |
| OPEN-02 | Stage 00 증거 파일 | **해소** | `~/avstack/logs/glxinfo_nvidia_prime.txt` 실존 확인 |
| OPEN-03 | Claude Code 계정 유형 | 미정 | Pro/Max/Team/Console 중 결정. 회사 계정이면 조직 정책 확인 |
| OPEN-04 | Git 원격 저장소 | **해소** | private GitHub remote `hjjung-katech` (SSH)로 확정. 브랜치 정책은 8.5 |
| OPEN-05 | MORAI 26.R1 계정 권한 | 미확인 | Stage 01 Launcher 로그인에서 확인. Scenario Runner 설치 권한 포함 |
| OPEN-06 | VERSIONS.lock | 미생성 | Claude Code 설치 시 `>>`로 자동 생성 |
| OPEN-07 | CLAUDE.md 정합 | **해소** | 확정본으로 배치 완료 |

---

## 1. 현재 결론

이 머신은 MORAI SIM과 Scenario Runner 검증용 기본 환경으로 사용 가능하다. 단, 기본 OpenGL renderer는 Intel iGPU이므로 MORAI Launcher, MORAI SIM, Scenario Runner는 반드시 NVIDIA PRIME offload 환경변수로 실행한다.

| 항목 | 현재 상태 | 판단 |
|---|---:|---|
| OS | Ubuntu 22.04.5 LTS | 적합 |
| Session | X11 | 적합 |
| 원격 접속 | NoMachine over GNOME Xorg | 사용 가능 |
| DISPLAY | `:1` | 사용 가능 |
| NVIDIA Driver | 580.159.03 | 정상 |
| GPU | RTX 3050 Laptop, 4GB VRAM | 사용 가능, 여유는 크지 않음 |
| PRIME mode | on-demand | 정상 |
| 기본 OpenGL | Intel Mesa | 일반 실행 시 Intel 사용 |
| NVIDIA PRIME OpenGL | NVIDIA RTX 3050 확인 | Stage 00 PASS |
| Docker | 미설치 | 현재 단계에서는 문제 아님 |
| git | 설치·identity·init 완료 | 사용 가능 |
| MORAI Launcher | `~/avstack/morai/launcher`에 배치 | Stage 01 준비됨 |

핵심 운영 원칙:

- `~/avstack`은 실행환경(로그, MORAI, 지도, 시나리오, rosbag). Git 제외.
- `~/avstack-control`은 Git 관리 제어 저장소.
- **3계층 기록 모델**: 상태·이력 = TSV / 증거 원본 = `~/avstack/logs·runs` 파일 / 절차·설명 = `runbooks/` Markdown.
- TSV는 손으로 수정하지 않고 기록 스크립트로만 추가.
- 각 Stage는 Gate를 통과해야 다음 Stage로 진행.
- Claude Code는 `~/avstack-control`에서만 실행. `~/avstack` 전체를 열지 않음.
- Docker/Autoware는 Stage 05 통과 후 진행.

---

## 2. 공식 근거와 적용 범위

### 2.1 MORAI Scenario Runner

Scenario Runner는 ASAM OpenSCENARIO `.xosc`를 로드하고 MORAI SIM과 gRPC로 통신하여 차량·물체를 제어한다. 시나리오는 MGeo 지도 기반이다.

```text
.xosc 시나리오 -> Scenario Runner -> gRPC -> MORAI SIM
```

`.xosc`는 MORAI SIM 본체가 여는 파일이 아니라 Scenario Runner가 로드하는 파일이다.

### 2.2 버전 판단

Scenario Runner 1.7.0: Ubuntu 20.04/22.04 지원, MORAI SIM: Drive 26.R1 호환. 현재 조합(Ubuntu 22.04.5 + 26.R1 + SR 1.7.0)이 가장 보수적이다.

### 2.3 ROS2와 Autoware

Autoware source install prerequisite: Ubuntu 22.04 + ROS2 Humble. 안정 release는 tag checkout(예: 1.8.0). 현재 blocker는 Scenario Runner GUI이므로 설치 보류.

### 2.4 Claude Code

요구사항(Ubuntu 20.04+, RAM 4GB+, 인터넷, shell) 충족. 용도는 기록·스크립트·설정 관리와 로그 분석 보조로 한정.

---

## 3. 운영 아키텍처

```text
MORAI Scenario Runner  - .xosc/MGeo 시나리오 실행, gRPC로 SIM 제어
MORAI SIM: Drive 26.R1 - 지도/차량/센서/객체 시뮬레이션, ROS2 Native topic
ROS2 Humble            - SIM과 외부 자율주행 SW 사이의 데이터 통신
Autoware               - Ego 자율주행 SW (External mode에서 Ego 제어)
```

| 구성 | 역할 |
|---|---|
| Scenario Runner | 시험 상황 생성기 |
| MORAI SIM | 가상세계, 센서, 차량동역학 |
| ROS2 | 센서·상태·제어 데이터 통신층 |
| Autoware | Ego 차량 자율주행 SW |
| Claude Code | 기록·로그 분석·스크립트 관리 보조 |
| Git | 제어 파일 변경 이력 관리 |

---

## 4. Stage 진행 계획

### 4.1 전체 Stage

| Stage | 이름 | 목적 | 현재 상태 |
|---:|---|---|---|
| 00 | Remote GPU Environment | NoMachine/X11/NVIDIA offload 확인 | PASS |
| 01 | MORAI Launcher/SIM Standalone | Launcher 및 SIM 단독 실행 | 준비 완료 |
| 02 | Scenario Runner Window | SR 창 표시 확인 (AVS-001) | TODO |
| 03 | MORAI Example XOSC Built-in | 예제 `.xosc` Built-in 실행 | TODO |
| 04 | ROS2 Humble Host | ROS2 기본 통신 확인 | TODO |
| 05 | MORAI ROS2 Native Topic | MORAI ROS2 topic 확인 | TODO |
| 06 | Autoware Base | Autoware 실행 기반 확보 | TODO |
| 07 | MORAI-Autoware Topic Mapping | topic/message/frame 정합 | TODO |
| 08 | SR External Closed-loop | Autoware External mode 연동 | TODO |

### 4.2 Gate 원칙

다음 조건을 만족하기 전에는 다음 Stage로 넘어가지 않는다.

- 명령 실행 로그가 `~/avstack/runs`에 남아 있을 것
- PASS/FAIL 판정이 `records/stages.tsv`에 기록되어 있을 것
- 문제가 있으면 `records/issues.tsv`에 등록되어 있을 것
- 중요한 판단은 `records/decisions.tsv`에 기록되어 있을 것
- Stage 통과 시 CLAUDE.md의 Stage 현황 갱신 + 한 커밋으로 묶을 것 (8.4 컨벤션)

---

## 5. 디렉터리 구조

### 5.1 실행환경: `~/avstack` (Git 제외)

```bash
mkdir -p ~/avstack/{logs,runs,rosbags}
mkdir -p ~/avstack/morai/{launcher,sim,scenario_runner}
mkdir -p ~/avstack/maps/{morai_mgeo,autoware_lanelet2,pointcloud}
mkdir -p ~/avstack/scenarios/{xosc,test_suites}
```

| 경로 | 용도 |
|---|---|
| `logs` | 프로그램 로그, 진단 로그 (증거 원본) |
| `runs` | `script`로 저장한 터미널 원본 로그 (증거 원본) |
| `morai/launcher` | **MoraiLauncher_lin.x86_64 배치 완료** |
| `morai/sim`, `morai/scenario_runner` | Launcher가 설치하는 SIM/SR (설치 위치는 Stage 01에서 확인) |
| `maps` | MGeo, Lanelet2, pointcloud map |
| `scenarios` | `.xosc` 및 test suite |
| `rosbags` | rosbag |

### 5.2 관리 저장소: `~/avstack-control` (Git 관리)

```bash
mkdir -p ~/avstack-control/{scripts,env,records,runbooks,.claude}
```

| 경로 | 용도 |
|---|---|
| `scripts` | 실행·진단·기록 스크립트 |
| `env` | ROS2, DDS 등 환경 파일 |
| `records` | TSV 기반 stage/issue/decision/commands 기록 |
| `runbooks` | 안정화된 절차서 (이 가이드 포함, 27장) |
| `.claude` | Claude Code 프로젝트 설정 |

---

## 6. TSV 기반 기록 체계

### 6.1 3계층 기록 모델 (v1.2 명시)

| 계층 | 매체 | 예 | 수정 방법 |
|---|---|---|---|
| 상태·이력 | `records/*.tsv` | Stage 판정, 이슈, 결정 | 기록 스크립트로만 추가 |
| 증거 원본 | `~/avstack/logs`, `~/avstack/runs` | glxinfo 출력, Player.log, script 세션 로그 | 생성 후 수정 금지, TSV에서 경로로 참조 |
| 절차·설명 | `runbooks/*.md` | 이 가이드, Stage 절차서 | 버전 개정 시에만 수정 |

"TSV로 한정"은 1계층(상태·이력)에만 적용된다. 증거 파일과 runbook Markdown은 각자의 계층에서 정상적인 구성요소다.

### 6.2 초기화 (파일이 없을 때만)

```bash
printf 'date\tstage\tstatus\tsummary\tevidence\tnext\n' > ~/avstack-control/records/stages.tsv
printf 'id\tdate\tstage\tstatus\tseverity\tsymptom\thypothesis\tevidence\tnext\tresolution\n' > ~/avstack-control/records/issues.tsv
printf 'id\tdate\tstatus\tdecision\treason\n' > ~/avstack-control/records/decisions.tsv
printf 'date\tstage\tcommand\tevidence\tnote\n' > ~/avstack-control/records/commands.tsv
```

### 6.3 시딩할 초기 기록

```bash
~/avstack-control/scripts/record_stage.sh 00_remote_gpu PASS "NVIDIA PRIME OpenGL confirmed" "~/avstack/logs/glxinfo_nvidia_prime.txt" "Stage01 MORAI Launcher"
~/avstack-control/scripts/record_issue.sh AVS-001 02_scenario_runner OPEN HIGH "Start Scenario Runner button active but no window" "OpenGL offload or runtime dependency issue" "~/avstack/logs/glxinfo_nvidia_prime.txt" "Run MORAI Launcher with NVIDIA offload script"
~/avstack-control/scripts/record_decision.sh ADR-001 ACCEPTED "Use NVIDIA PRIME offload for MORAI" "Default OpenGL uses Intel and NVIDIA offload is confirmed"
~/avstack-control/scripts/record_decision.sh ADR-002 ACCEPTED "Defer Docker installation" "Current blocker is MORAI and Scenario Runner GUI execution"
~/avstack-control/scripts/record_decision.sh ADR-003 ACCEPTED "Use three-tier records: TSV, evidence logs, runbooks" "TSV for state, raw logs for evidence, markdown for procedures"
~/avstack-control/scripts/record_decision.sh ADR-004 ACCEPTED "Run Claude Code only in avstack-control" "Limit file access scope"
```

---

## 7. 원본 로그 저장 방식

각 Stage 시작 시:

```bash
script -af ~/avstack/runs/stage01_morai_$(date +%Y%m%d_%H%M%S).log
```

종료 시 `exit`.

원칙: 원본 로그는 `~/avstack/runs·logs`에 저장, TSV에는 경로만 기록, Git 제외, Claude Code에 넘기기 전 민감정보 점검:

```bash
grep -i -E "token|license|auth|password|passwd|key|secret" <logfile>
```

---

## 8. Git 관리 정책

### 8.1 Git 대상

포함: `records/*.tsv`, `scripts/*.sh`, `env/*`, `runbooks/*`, `CLAUDE.md`, `.claude/settings.json`
제외: `~/avstack` 전체, `~/.claude`, `~/.claude.json`, MORAI 바이너리/설치파일, 지도, rosbag, 로그 원본, 스크린샷, 라이선스/계정/토큰, `.claude/settings.local.json`

### 8.2 `.gitignore`

```gitignore
.claude/settings.local.json
.env
.env.*
secrets/
env/*secret*
env/*token*
env/*key*
env/*license*
*.log
*.bag
*.db3
*.mcap
*.pcd
*.png
*.jpg
*.mp4
*.zip
*.tar.gz
```

### 8.3 Git 상태와 첫 커밋

완료: `git init`, identity (Hojung Jung / hjjung2@katech.re.kr).
다음: records/scripts/env/설정/runbook 생성 후 첫 커밋.

```bash
cd ~/avstack-control
git add records scripts env runbooks CLAUDE.md .claude/settings.json .gitignore
git commit -m 'init: baseline avstack control records'
git log --oneline
```

### 8.4 커밋 컨벤션 (v1.2 확정)

**형식:** `<type>: <소문자 영어 한 줄>`

| type | 용도 | 예 |
|---|---|---|
| `init` | 최초 baseline | `init: baseline avstack control records` |
| `stage` | Stage 판정 기록 (TSV 행 + CLAUDE.md 현황 갱신을 한 커밋으로) | `stage: 01 morai launcher pass` |
| `issue` | 이슈 등록/해결 | `issue: open AVS-002 sim crash on map load` / `issue: resolve AVS-001 launcher env not passed to runner` |
| `adr` | 결정 기록 | `adr: 005 adopt claude code` |
| `script` | 스크립트 추가/수정 | `script: set morai dir to avstack morai launcher` |
| `env` | 환경 파일 변경 | `env: add cyclonedds config` |
| `claude` | Claude Code 설정 변경 | `claude: add ros2 allow rules for stage04` |
| `docs` | runbook/가이드 개정 | `docs: operations guide v1.2` |

**규칙:**

- 커밋은 이벤트 기반. 시간 기반("퇴근 전 커밋") 금지. 트리거는 Stage 판정, 이슈 등록/해결, ADR, 스크립트·설정·문서 변경.
- 원자성: 하나의 사건 = 하나의 커밋. Stage 통과 시 stages.tsv 행 + CLAUDE.md Stage 현황 갱신을 반드시 같은 커밋에 묶는다 (이력만 봐도 시점별 상태가 재구성되도록).
- `git add`는 경로 명시를 기본으로 한다 (`git add records CLAUDE.md`). `.gitignore`를 신뢰하더라도 초기에는 `git add -A`를 피한다.
- 이슈 해결 커밋 메시지에는 원인을 요약한다 (`issue: resolve AVS-001 <원인 한 줄>`). issues.tsv의 resolution과 대응.
- 주요 Gate(Stage 03, 05, 08) 통과 시 태그를 남긴다: `git tag -a gate-03-xosc-builtin -m 'scenario runner builtin verified'`.
- 민감정보·로그·대용량 파일이 staged 되었는지 커밋 전 `git status`로 확인한다.

### 8.5 브랜치 정책 (v1.3 신설)

**원칙: `main` 단일 브랜치 (trunk-based).** 이 저장소는 제어·기록 저장소이며 실행 데이터(코드가 아님)를 다루므로, 장수 브랜치나 PR 흐름을 두지 않고 `main`에 직접 커밋한다. 원격은 private GitHub `hjjung-katech` (SSH), 커밋 후 `git push`로 동기화한다 (OPEN-04 해소).

예외는 다음 두 경우뿐이다.

1. **코드 개발은 별도 저장소에서.** 자율주행 SW·노드·연동 코드를 본격적으로 개발할 때는 이 저장소에 브랜치를 만들지 않고 별도 저장소를 사용한다. 이 저장소는 절차·기록·설정 전용으로 유지한다.
2. **위험한 스크립트 변경 시 하루짜리 `try/` 브랜치.** 되돌리기 어렵거나 실행 환경을 망가뜨릴 수 있는 스크립트 변경은 `try/<요약>` 브랜치에서 시험하고, 검증되면 `main`에 머지한 뒤 즉시 브랜치를 삭제한다. 하루 안에 정리한다 — 살아남는 `try/` 브랜치를 두지 않는다.

```bash
git switch -c try/risky-bootstrap-change   # 시험 시작
# ... 검증 ...
git switch main && git merge try/risky-bootstrap-change
git branch -d try/risky-bootstrap-change   # 즉시 삭제
```

---

## 9. Stage 00 상세 기록

확인 결과: Ubuntu 22.04.5 / X11 / DISPLAY :1 / NoMachine / NVIDIA 580.159.03 / RTX 3050 / PRIME on-demand.
기본 OpenGL: `Mesa Intel(R) Graphics (ADL GT2)`. NVIDIA PRIME OpenGL: `NVIDIA GeForce RTX 3050 Laptop GPU/PCIe/SSE2`.
증거: `~/avstack/logs/glxinfo_nvidia_prime.txt` (실존 확인).

**판정: Stage 00 PASS.** 결정: MORAI 계열은 NVIDIA PRIME offload로 실행 (ADR-001).

---

## 10. Stage 01: MORAI Launcher/SIM Standalone

### 10.1 목적

MORAI Launcher와 SIM이 NoMachine X11 + NVIDIA PRIME offload 환경에서 정상 실행되는지 확인.

### 10.2 실행 스크립트: `~/avstack-control/scripts/run_morai_launcher_nvidia.sh` (v1.2 경로 반영)

```bash
#!/usr/bin/env bash
set -euo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
MORAI_DIR="${MORAI_DIR:-$HOME/avstack/morai/launcher}"
MORAI_BIN="${MORAI_BIN:-MoraiLauncher_lin.x86_64}"
LOG_DIR="$HOME/avstack/logs"
LOG_FILE="$LOG_DIR/MoraiLauncher_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"
if [ ! -f "$MORAI_DIR/$MORAI_BIN" ]; then
  echo "[ERROR] $MORAI_DIR/$MORAI_BIN not found" >&2
  exit 1
fi
chmod +x "$MORAI_DIR/$MORAI_BIN"
echo "[INFO] MORAI_DIR=$MORAI_DIR"
echo "[INFO] MORAI_BIN=$MORAI_BIN"
echo "[INFO] LOG_FILE=$LOG_FILE"
cd "$MORAI_DIR"
./"$MORAI_BIN" -logFile "$LOG_FILE"
```

기본값이 실제 배치와 일치하므로 인자 없이 실행 가능. 경로/파일명이 바뀌면 `MORAI_DIR=`, `MORAI_BIN=` 환경변수로 덮어쓴다.

### 10.3 실행 절차

```bash
script -af ~/avstack/runs/stage01_morai_$(date +%Y%m%d_%H%M%S).log
~/avstack-control/scripts/run_morai_launcher_nvidia.sh
# 다른 터미널: watch -n 1 nvidia-smi
# 종료: exit
```

### 10.4 통과 기준

Launcher 창 표시 / 로그인 성공 (OPEN-05 확인 겸함) / SIM 설치·실행 / 기본 지도 로드 / nvidia-smi에 MORAI 프로세스 표시 / 정상 종료.

### 10.5 실패 시 확인

```bash
ps -ef | grep -i -E "morai|simulator|unity" | grep -v grep
find ~/.config ~/avstack/morai -type f \( -iname "*.log" -o -iname "Player.log" \) -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -50
tail -n 200 <logfile>
```

참고: Launcher가 SIM/SR을 어디에 설치하는지 Stage 01에서 확인하고 `records/commands.tsv`에 기록한다 (기본 설치 경로가 `~/avstack/morai` 밖일 수 있음 — 확인 후 5.1 표 갱신).

---

## 11. Stage 02: Scenario Runner Window (AVS-001)

### 11.1 현재 이슈

| 항목 | 내용 |
|---|---|
| ID | AVS-001 (OPEN, HIGH) |
| Symptom | Start Scenario Runner 버튼은 활성화되어 있으나 클릭 후 창이 뜨지 않음 |

가설 우선순위: (1) Launcher가 Intel OpenGL 환경을 상속 (2) Runner dependency 누락 (3) Launcher의 자식 프로세스 환경변수 전달 실패 (4) Runner 순간 crash.

### 11.2 진단 명령 (v1.2 경로 반영)

```bash
find ~/avstack/morai ~/.config -type f | grep -i scenario
find ~/avstack/morai -type f -perm -111 | grep -i scenario
find ~/.config ~/avstack/morai -type f \( -iname "*.log" -o -iname "Player.log" \) -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -50
# 실행 파일 발견 시:
cd <SR 폴더> && chmod +x ./<SR실행파일>.x86_64
ldd ./<SR실행파일>.x86_64 | grep "not found"
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only ./<SR실행파일>.x86_64
```

### 11.3 통과 기준과 실패 분기

통과: SR 창 표시, 기본 UI 진입, 강제 종료 없음.

| 증상 | 우선 의심 |
|---|---|
| 프로세스 미생성 | Launcher 실행 명령 실패 |
| 프로세스 생성 후 소멸 | Runner crash |
| ldd not found | dependency 누락 |
| cannot open display | DISPLAY/Xauthority |
| 직접 실행만 성공 | Launcher 환경변수 전달 문제 |
| 창은 뜨나 SIM 연결 실패 | gRPC/SIM 연결 (별도 이슈로 분리) |

이 Stage는 Claude Code의 첫 실전 투입 대상이다 (18.5).

---

## 12. Stage 03: MORAI Example XOSC Built-in

```bash
find ~/avstack/morai ~/avstack/scenarios -iname "*.xosc" | head -50
```

절차: SIM 실행 → SR 실행 → 예제 `.xosc` 로드 → Run > Start Simulation → Ego Control = Built-in → Ego/NPC 동작 확인 → Stop.
통과: `.xosc` 로드 / MGeo 로드 / Start 성공 / Built-in 동작 / 종료 가능. 통과 시 `gate-03-xosc-builtin` 태그.

---

## 13. Stage 04: ROS2 Humble Host

### 13.1 환경 파일: `~/avstack-control/env/ros2_humble.env`

```bash
source /opt/ros/humble/setup.bash
export ROS_DISTRO=humble
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_DOMAIN_ID=42
```

### 13.2 테스트

```bash
source ~/avstack-control/env/ros2_humble.env
ros2 doctor --report
# 터미널1: ros2 run demo_nodes_cpp talker
# 터미널2: ros2 run demo_nodes_cpp listener
```

통과: listener 수신 / topic list 정상 / DOMAIN_ID 고정. 주의: `ROS_LOCALHOST_ONLY=1` 금지.
이 단계 진입 시 19.2의 ros2 allow 규칙 추가 (`claude:` 커밋).

---

## 14. Stage 05: MORAI ROS2 Native Topic

```bash
source ~/avstack-control/env/ros2_humble.env
ros2 node list
ros2 topic list | sort
ros2 topic echo /clock --once
ros2 topic hz /clock
```

통과: `/clock` 및 sensor/status topic 확인, 데이터 수신. 통과 시 `gate-05-ros2-native` 태그.
주의: `ros2 topic echo`는 `--once` 또는 `timeout 5`와 함께만.

---

## 15. Stage 06: Autoware Base

Docker 미설치 유지. Stage 05 통과 후 source vs Docker 선택 (ADR로 기록). 4GB VRAM이므로 full perception 후순위, localization/planning/control 중심.

---

## 16. Stage 07: MORAI-Autoware Topic Mapping

확인 대상: `/clock`, `/tf`, `/tf_static`, LiDAR PointCloud2, Camera, IMU, GNSS/Odometry, vehicle status, control command, gear, turn signal, operation mode.
주의: MGeo ≠ Autoware map (pointcloud + Lanelet2 별도 필요). topic 이름뿐 아니라 message type, frame_id, timestamp, QoS 정합 필요.

---

## 17. Stage 08: Scenario Runner External Closed-loop

순서: SIM 실행 → ROS2 topic 수신 → Autoware 실행 → localization → route → planning/control 출력 → SR 실행 → `.xosc` 로드 → Start → Ego Control = External → Autoware가 Ego 제어 확인.
External에서 Ego 정지 시: Autoware control command 출력 → MORAI 수신 → vehicle interface mapping → operation mode → localization → `/clock`·`/tf` 정합 순으로 확인. 통과 시 `gate-08-closed-loop` 태그.

---

## 18. Claude Code 통합

### 18.1 설치

```bash
curl -fsSL https://claude.ai/install.sh | bash -s stable
claude --version && claude doctor
claude --version >> ~/avstack/VERSIONS.lock
```

### 18.2 실행 위치와 접근 범위

`~/avstack-control`에서만 실행. `~/avstack` 전체 add-dir 금지.
로그 접근은 `.claude/settings.local.json`(Git 제외)에 영구 등록:

```json
{
  "permissions": {
    "additionalDirectories": ["~/avstack/logs", "~/avstack/runs"]
  }
}
```

### 18.3 인증

첫 실행 시 브라우저 로그인 (NoMachine 원격 데스크톱 내 브라우저. 자동으로 안 열리면 터미널의 URL 복사). Pro/Max/Team/Enterprise/Console 계정 필요 (OPEN-03).

### 18.4 첫 세션 검증 체크리스트

```text
1. /memory        → CLAUDE.md 로드 확인
2. /permissions   → deny에 sudo, prime-select 등 확인
3. "records/stages.tsv 요약해줘"        → 파일 읽기 확인
4. "git status 확인하고 커밋할 것 알려줘" → git 연동 확인
```

통과 시:

```bash
~/avstack-control/scripts/record_decision.sh ADR-005 ACCEPTED "Adopt Claude Code in avstack-control" "CLAUDE.md rules and permission settings verified in first session"
cd ~/avstack-control && git add records && git commit -m 'adr: 005 adopt claude code'
```

### 18.5 첫 실전 투입: AVS-001

Stage 01 통과 후 SR 창이 안 뜨면 Claude Code 세션에서:

```text
AVS-001 진단해줘. ~/avstack/logs의 최신 MoraiLauncher 로그와 Player.log를 읽고,
Scenario Runner 실행 파일 위치 추정, ldd 확인 명령, 원인 후보를 우선순위로 정리해줘.
단, 로그에 민감정보가 있는지 grep으로 먼저 확인해줘.
```

---

## 19. Claude Code 프로젝트 설정

### 19.1 `CLAUDE.md` — 확정본 배치 완료 (OPEN-07 해소)

전문은 배치된 파일이 원본이다. 갱신 트리거: Stage 통과(현황 섹션), 이슈 등록/해결(열린 이슈 섹션), 운영 규칙 변경. 갱신은 해당 stage/issue 커밋에 묶는다.

### 19.2 `.claude/settings.json` 최종본

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "autoUpdatesChannel": "stable",
  "permissions": {
    "allow": [
      "Bash(nvidia-smi)",
      "Bash(nvidia-smi *)",
      "Bash(glxinfo *)",
      "Bash(ldd *)"
    ],
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf *)",
      "Bash(prime-select *)",
      "Bash(nvidia-settings *)",
      "Bash(curl *)",
      "Bash(wget *)",
      "Read(~/.ssh/**)",
      "Read(~/avstack/morai/**/*license*)",
      "Read(./env/**/*secret*)",
      "Read(./env/**/*token*)",
      "Read(./env/**/*key*)",
      "Read(.env)",
      "Read(./secrets/**)"
    ]
  }
}
```

Stage 04 진입 시 allow 추가: `"Bash(ros2 topic *)"`, `"Bash(ros2 node *)"`, `"Bash(ros2 doctor *)"`.

### 19.3 보안 한계와 sandbox

deny 규칙은 Claude의 내장 도구와 인식 가능한 명령에만 적용된다. 서브프로세스의 직접 파일 접근은 막지 못하므로 **deny = 보안 경계가 아니다.** MORAI 라이선스 보호가 중요해지면(SIM 설치 후) sandbox(Ubuntu bubblewrap, OS 수준 격리) + `sandbox.filesystem.denyRead` 도입을 검토하고 ADR로 기록한다.

---

## 20. 기록 스크립트 (모두 `~/avstack-control/scripts/`, `chmod +x`)

`record_stage.sh`(6열), `record_issue.sh`(10열), `record_decision.sh`(5열), `capture_env_snapshot.sh`(환경 스냅샷), `run_morai_launcher_nvidia.sh`(10.2). 전문은 bootstrap_avstack_control.sh v1.2에 포함. TSV 직접 편집 금지 — 이 스크립트로만 기록.

---

## 21. 보안 원칙

Claude Code 접근 금지: MORAI 계정/라이선스, API key, token, SSH key, 사내 IP 포함 설정, 업체 비공개 문서, MORAI 바이너리 디렉터리 전체.
로그 전달 전 점검: `grep -i -E "token|license|auth|password|passwd|key|secret" <logfile>`. 발견 시 마스킹 후 분석. sandbox 기준은 19.3.

---

## 22. Docker 판단

미설치 유지. Stage 05 통과 후 Autoware 방식 선택 시 도입, ADR로 기록.

---

## 23. 현재 주요 이슈: AVS-001

11장 참조. 다음 액션: NVIDIA offload script로 Launcher 실행 → SR 재시도 → ps/nvidia-smi 확인 → 실패 시 직접 실행 + ldd + Player.log → issues.tsv/stages.tsv 기록.

---

## 24. 바로 다음 작업 순서 (0.2와 동일)

```text
1. bootstrap_avstack_control.sh (v1.2) 실행
2. 이 가이드를 runbooks/operations_guide.md로 배치 (27장)
3. 첫 커밋: git commit -m 'init: baseline avstack control records'
4. Claude Code 설치 → doctor → 버전 기록 → 인증 → 첫 세션 검증(18.4) → adr: 005 커밋
5. Stage 01: script 로그 → run_morai_launcher_nvidia.sh → watch nvidia-smi
6. record_stage.sh 판정 + CLAUDE.md 현황 갱신 → 'stage: 01 ...' 커밋
7. Stage 02: Start Scenario Runner → 실패 시 AVS-001 진단 (18.5)
```

---

## 25. 참고 문서

- MORAI Scenario Runner 개요: https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/-2
- MORAI Scenario Runner Release Notes: https://help-morai-sim.scrollhelp.site/morai-scenario-runner-kr/-7
- MORAI SIM: Drive 26.R1.0 Release Notes: https://help-morai-sim.scrollhelp.site/ko/morai-sim-drive/26.R1/morai-sim-drive-26-r1-0
- Autoware Source Installation: https://autowarefoundation.github.io/autoware-documentation/main/installation/autoware/source-installation/
- Claude Code Setup: https://code.claude.com/docs/en/setup
- Claude Code Permissions: https://code.claude.com/docs/en/permissions
- Claude Code Sandboxing: https://code.claude.com/docs/en/sandboxing

---

## 26. 최종 요약

| 항목 | 결정 |
|---|---|
| 실행환경 | `~/avstack` (MORAI Launcher 배치 완료) |
| 관리 저장소 | `~/avstack-control` (git init 완료, 첫 커밋 대기) |
| git identity | Hojung Jung / hjjung2@katech.re.kr |
| 기록 방식 | 3계층: TSV(스크립트로만) + 증거 원본 + runbooks |
| 커밋 컨벤션 | `<type>: <내용>` 이벤트 기반, Gate 태그 |
| MORAI 실행 | `run_morai_launcher_nvidia.sh` (NVIDIA offload, 경로 확정) |
| Docker | 보류 (Stage 05 이후) |
| Claude Code | `~/avstack-control` 전용, settings.local.json으로 logs/runs 접근 |
| 현재 Stage | 00 PASS → 초기화 → Stage 01 (준비 완료) |
| 주요 이슈 | AVS-001 SR 창 미표시 (OPEN) |

---

## 27. 이 문서의 위치와 활용 규칙 (v1.2 신설)

### 27.1 위치

이 가이드는 `~/avstack-control/runbooks/operations_guide.md`로 저장하고 Git으로 관리한다. 파일명에 버전을 넣지 않는다 — 버전은 문서 머리말과 Git 히스토리가 관리한다.

### 27.2 역할 분담 (중복 기록 방지)

| 문서 | 역할 | 갱신 주기 |
|---|---|---|
| `runbooks/operations_guide.md` (이 문서) | 절차·기준·구조의 참조 원본 | 구조나 절차가 바뀔 때만 (버전 업 + `docs:` 커밋) |
| `records/*.tsv` | 상태·이력의 source of truth | 사건 발생 즉시 (스크립트로) |
| `CLAUDE.md` | Claude Code용 규칙 + 현황 요약 | Stage/이슈 변동 시 |

이 문서의 0장(진행 현황)은 **개정 시점의 스냅샷**이며 매일 갱신하지 않는다. "지금 어디까지 했나"는 항상 `records/stages.tsv`와 CLAUDE.md에서 확인한다.

### 27.3 사용 방법

- 사람: Stage 시작 전 해당 장을 열어 절차와 통과 기준을 확인한다.
- Claude Code: runbooks/는 저장소 안에 있으므로 세션에서 바로 참조 가능하다. 사용 예 — "runbooks/operations_guide.md의 11장 절차대로 AVS-001 진단을 준비해줘".
- 업체 문의: 해당 Stage 장 + 관련 issues.tsv 행 + 증거 로그 경로를 묶어 전달한다.

### 27.4 개정 규칙

절차·기준·구조가 바뀌면 개정 이력 표에 행을 추가하고 문서 버전을 올린 뒤 `docs: operations guide v1.x` 커밋. 사소한 오타는 버전 업 없이 `docs:` 커밋만 한다.