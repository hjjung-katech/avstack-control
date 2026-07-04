# AVS-007 계층 분리 진단 계획 (Stage 05 재검증)

| 항목 | 내용 |
|---|---|
| 문서명 | AVS-007 계층 분리 진단 계획 |
| 버전 | v1.0 |
| 작성일 | 2026-07-04 |
| 위치 | `~/avstack-control/runbooks/avs-007_layer_diagnosis.md` |
| 대상 이슈 | AVS-007 (MORAI ROS2 토픽 미수신 / rosbridge header.seq) |
| 관련 Stage | Stage 05 (MORAI ROS2 Native Topic) |
| 상위 문서 | integrated_roadmap.md, framework_design_note_v1.1.md |

---

## 1. 진단 목적

Stage 05 실패(MORAI 토픽 미수신)의 원인을 **계층별로 분리·귀속**한다. 구체적으로 다음 세 가지 질문에 실측 근거로 답한다.

1. **귀속 질문**: 실패 원인이 벤더(SIM 내장 ros2cs) / 환경 설정(Domain·RMW) / 진단 도구(QoS) 중 어디에 있는가?
2. **반증 질문**: "Autoware(구독자)가 없어서 생긴 문제"라는 가설을 반증 또는 입증할 수 있는가?
3. **경로 질문**: rosbridge가 평가 파이프라인의 데이터 소스 자격이 있는가, 아니면 진단 도구로 격하해야 하는가?

**진단이 아닌 것**: 이 계획은 문제를 "고치는" 작업이 아니다. 수정 시도(패치, 재설치)는 진단 완료 후 별도 실험으로 분리한다. 진단 중 시스템 상태를 바꾸는 행위는 금지한다.

---

## 2. 진단 설계 원칙

- **실험 카드 규율**: 각 테스트는 가설 1개, 변경점 1개(또는 0개=관찰만), 기대 결과, 중지 조건을 착수 전에 선언한다.
- **계층 순서 고정**: D1(DDS) → D2(Discovery) → D3(QoS) → D4(구독자 가설) → D5(제어 경로). 하위 계층이 FAIL이면 상위 계층 테스트는 의미가 없으므로 그 시점에서 진단을 종료하고 귀속을 확정한다.
- **전역 설정 불변**: `.bashrc`, `prime-select`, 드라이버, SIM 설치 파일을 건드리지 않는다. 모든 환경 변수는 해당 터미널 세션 또는 wrapper 스크립트 안에서만 적용한다.
- **기록**: 각 테스트는 `script`로 원본 로그를 남기고, 결과를 commands.tsv에 1행씩 기록한다. 최종 판정은 issues.tsv의 AVS-007 갱신과 (필요 시) 신규 ADR로 반영한다.

---

## 3. 사전 조건 (모든 테스트 공통)

| 조건 | 확인 방법 |
|---|---|
| MORAI SIM 실행 중, 지도 로드 완료 | GUI 확인 + `nvidia-smi`에 SIM 프로세스 |
| SIM의 ROS2 설정 UI에서 Native 활성화 | 스크린샷 저장 → `~/avstack/logs/avs007_sim_ros2_ui.png` |
| SIM UI에 표시된 Domain ID 값 기록 | 아래 D2에서 사용. **이 값을 먼저 적는다: ______** |
| 호스트 ROS2 환경 | `source ~/avstack-control/env/ros2_humble.env` (DOMAIN_ID=42, CycloneDDS) |
| 원본 로그 시작 | `script -af ~/avstack/runs/avs007_diag_$(date +%Y%m%d_%H%M%S).log` |
| rosbridge/기타 브리지 프로세스 **전부 종료** | `pgrep -af rosbridge` 결과 없음 (D1~D4는 Native 경로만 본다) |

> 주의: 지난 세션에서 client_count 32가 관측되었다. 잔존 rosbridge/좀비 클라이언트가 있으면 측정이 오염되므로, 진단 시작 전 반드시 정리하고 정리 결과도 로그에 남긴다.

---

## 4. 테스트 카드

### D1. DDS Participant 존재 검증 (최하위 계층)

| 항목 | 내용 |
|---|---|
| **목적** | MORAI SIM 프로세스가 DDS participant를 실제로 생성하는지 확인한다. 여기서 아무것도 없으면 상위 계층(도메인, QoS, 구독자)은 전부 무의미하다. |
| **가설 H1** | SIM 내장 ros2cs가 초기화에 실패하여 DDS participant 자체가 생성되지 않는다 (벤더 귀속). |
| **변경점** | 없음 (순수 관찰) |

**절차**

```bash
# 1. SIM 프로세스 PID 확보
SIM_PIDS=$(pgrep -f -i "morai|simulator" | paste -sd'|')
echo "SIM_PIDS=$SIM_PIDS"

# 2. SIM 프로세스가 UDP 포트(RTPS discovery 대역 7400~7500)를 열었는지
ss -ulpn | grep -E "$SIM_PIDS" | tee /tmp/d1_ports.txt

# 3. RTPS discovery 멀티캐스트 패킷 관찰 (60초)
sudo timeout 60 tcpdump -i any -c 50 udp portrange 7400-7500 -nn | tee /tmp/d1_rtps.txt
```

**판정**

| 관측 | 판정 | 귀속 | 다음 |
|---|---|---|---|
| SIM PID가 7400대 UDP 포트 보유 + RTPS 패킷 관측 | **D1 PASS** — participant 존재 | — | D2로 진행 |
| 포트 없음 / SIM 발신 RTPS 패킷 없음 | **D1 FAIL** — ros2cs 미동작 | **벤더 확정** | 진단 종료. MORAI 문의에 이 실측(포트 목록, tcpdump 요약) 첨부 |
| 다른 프로세스(daemon 등)의 패킷만 관측 | 판별 곤란 | — | ros2 daemon 종료 후 재시도 1회, 그래도 모호하면 FAIL 처리 |

**중지 조건**: tcpdump 60초 2회 시도로 종료. 그 이상 반복하지 않는다.

---

### D2. Domain ID / RMW 정합 검증

| 항목 | 내용 |
|---|---|
| **목적** | participant는 존재하는데 호스트에서 안 보이는 경우, Domain ID 불일치 또는 RMW 조합(Fast DDS↔CycloneDDS) 문제인지 판별한다. |
| **가설 H2a** | SIM은 Domain 0(기본값)으로 발행 중인데 호스트는 42를 보고 있다. |
| **가설 H2b** | SIM 내장 ros2cs(Fast DDS 계열)와 호스트 CycloneDDS 간 상호발견이 실패한다 (shared-memory/interface 설정 등). |
| **변경점** | 터미널 세션 한정 환경변수 1개씩 (ROS_DOMAIN_ID 또는 RMW_IMPLEMENTATION). 동시에 두 개를 바꾸지 않는다. |

**절차**

```bash
# 0. daemon 캐시 배제 (모든 시도 전 공통)
ros2 daemon stop

# 1. 기준선: 현재 설정(42, CycloneDDS)
ros2 topic list | tee /tmp/d2_base.txt

# 2. H2a 검증: SIM UI에 기록한 Domain ID로 맞춰서 (예: 0)
ROS_DOMAIN_ID=<SIM_UI_값> ros2 topic list | tee /tmp/d2_domain.txt

# 3. H2b 검증: RMW를 Fast DDS로 (Domain은 SIM 값 유지)
#    (rmw_fastrtps 미설치 시: sudo apt install ros-humble-rmw-fastrtps-cpp — 이 설치는 허용)
ROS_DOMAIN_ID=<SIM_UI_값> RMW_IMPLEMENTATION=rmw_fastrtps_cpp ros2 topic list | tee /tmp/d2_rmw.txt

# 4. 각 시도에서 토픽이 보이면 즉시 상세 확인
ros2 topic list | grep -i -E "ego|morai|clock|vehicle"
```

**판정**

| 관측 | 판정 | 귀속 | 다음 |
|---|---|---|---|
| 2번에서 MORAI 토픽 출현 | **H2a 확정** — Domain 불일치 | 환경 설정 | env 파일 수정은 별도 결정(ADR). D3로 진행 |
| 3번에서만 출현 | **H2b 확정** — RMW 조합 문제 | 환경 설정 | RMW 표준 채택 여부 ADR. D3로 진행 |
| 어느 조합에서도 미출현 (D1은 PASS) | participant는 있으나 publisher 없음 | 벤더 유력 | D4(lazy publisher) 1회만 확인 후 종료 |

**중지 조건**: Domain × RMW 2×2 = 최대 4조합. 그 외 조합 탐색 금지 (조합 폭발 방지).

---

### D3. QoS 착시 검증 (echo 침묵 판별)

| 항목 | 내용 |
|---|---|
| **목적** | "토픽은 목록에 있는데 echo가 침묵"하는 경우, publisher QoS(best-effort 등)와 echo 기본값(reliable) 불일치인지 확인한다. Stage 05 실패의 오진 가능성을 제거한다. |
| **가설 H3** | 토픽 미수신처럼 보인 것은 진단 도구의 QoS 기본값 때문이다. |
| **전제** | D2까지에서 토픽이 목록에 보이는 상태 |
| **변경점** | echo 명령의 QoS 옵션만 |

**절차**

```bash
# 1. publisher의 실제 QoS 프로파일 확인 (가장 중요한 1줄)
ros2 topic info -v /Ego_topic | tee /tmp/d3_qos.txt
# → Reliability / Durability / History 값을 기록

# 2. publisher QoS에 맞춰 echo
ros2 topic echo /Ego_topic --qos-reliability best_effort --qos-durability volatile --once

# 3. 수신되면 주파수 실측 (평가 파이프라인 소스 자격 판단용 기초 데이터)
timeout 15 ros2 topic hz /Ego_topic | tee /tmp/d3_hz.txt
```

**판정**

| 관측 | 판정 | 다음 |
|---|---|---|
| QoS 맞추자 수신 | **H3 확정** — 착시였음 | Stage 05 판정문 수정 (미수신 아님 → QoS 문서화). verify_topics.sh에 QoS 옵션 반영 |
| QoS 맞춰도 침묵 | publisher가 데이터를 안 쏨 | 벤더 유력. D4로 |

---

### D4. 구독자 가설 검증 (lazy publisher / "Autoware 부재" 반증)

| 항목 | 내용 |
|---|---|
| **목적** | "구독자(Autoware)가 없어서 발행이 안 된다"는 가설을 직접 검증한다. Autoware의 구독자 역할을 1줄 더미로 대체하여, Autoware 설치 없이 이 가설을 입증/반증한다. |
| **가설 H4** | SIM의 publisher는 구독자가 붙어야 발행을 시작한다 (lazy publisher). |
| **변경점** | 더미 구독자 프로세스 1개 추가 |

**절차**

```bash
# 1. 더미 구독자를 60초 유지 (터미널 A)
#    메시지 타입은 ros2 topic info 결과 또는 morai_ros2_msgs 빌드 산출물 사용
timeout 60 ros2 topic echo /Ego_topic --qos-reliability best_effort &

# 2. 구독자 유지 상태에서 (터미널 B)
ros2 topic list | grep -i -E "ego|morai"
timeout 15 ros2 topic hz /Ego_topic

# 3. 구독자 종료 후 재확인 (발행이 멈추는지)
```

**판정 — 이것이 "Autoware 부재" 질문의 최종 답이다**

| 관측 | 판정 | 의미 |
|---|---|---|
| 구독자 유무와 무관하게 발행 없음 | **H4 기각** | Autoware 부재와 **무관**. 벤더 귀속 확정 |
| 구독자 붙일 때만 발행 시작 | **H4 채택** | "구독자 부재" 관련 있음 — 단 해법은 Autoware가 아니라 **임의의 구독자**. 파이프라인 설계상 rosbag record가 항상 구독자 역할을 하므로 실운영 문제 아님. 이 특성을 api_contract/topics 문서에 명시 |

---

### D5. 제어 경로 역방향 검증 (Autoware publisher 역할 대체)

| 항목 | 내용 |
|---|---|
| **목적** | Autoware의 나머지 역할(제어 명령 발행)을 `ros2 topic pub`으로 대체하여, 호스트→SIM 방향 통신이 성립하는지 확인한다. D1~D4가 SIM→호스트 방향이라면 D5는 역방향이다. |
| **가설 H5** | 호스트에서 발행한 ctrl_cmd를 SIM이 수신·반영한다 (수신 경로는 정상이다). |
| **전제** | SIM에서 Ego 스폰, 제어 모드를 외부 명령 수신 가능 상태로 설정 |
| **변경점** | 기존 자산 `send_ctrl_cmd.sh` 실행 |

**절차**

```bash
# 지난 세션 자산 재사용 (실측값으로 보정되어 있음)
~/avstack-control/scripts/send_ctrl_cmd.sh
# GUI에서 Ego 반응(가감속/조향) 육안 확인 + 화면 녹화 또는 스크린샷
```

**판정**

| 관측 | 판정 | 의미 |
|---|---|---|
| Ego 반응 | **H5 채택** | 호스트→SIM 경로 정상. Autoware External 연동의 하드웨어적 전제 성립 |
| 무반응 | 수신 경로도 문제 | SIM ROS2 설정/토픽명/모드 확인 → MORAI 문의에 양방향 실패로 보강 |

---

## 5. 종합 판정 매트릭스

| D1 | D2 | D3 | D4 | 최종 귀속 | 후속 액션 |
|---|---|---|---|---|---|
| FAIL | — | — | — | **벤더 (ros2cs 미동작)** | MORAI 문의에 D1 실측 첨부, AVS-007 evidence 갱신, Stage 05 BLOCKED 유지 |
| PASS | Domain/RMW로 해결 | — | — | **환경 설정** | env 표준 변경 ADR, Stage 05 재시도 → PASS 가능 |
| PASS | PASS | QoS로 해결 | — | **진단 도구 (착시)** | Stage 05 판정 정정, verify_topics.sh 보강, 오진 회고 기록 |
| PASS | PASS | FAIL | H4 채택 | **lazy publisher 특성** | 문서화 + rosbag 상시 구독 전제 확인, Stage 05 조건부 PASS |
| PASS | PASS | FAIL | H4 기각 | **벤더 (publisher 무발행)** | MORAI 문의 보강 (participant는 있으나 발행 없음) |

**"Autoware를 쓰지 않아서 생긴 문제인가"에 대한 답**: 위 매트릭스의 모든 경로 중 Autoware 설치가 해법인 분기는 존재하지 않는다. H4 채택 시에도 필요한 것은 "임의의 구독자"이며, 이는 파이프라인의 rosbag record가 항상 충족한다. 이 문장을 실측으로 뒷받침하는 것이 본 진단의 핵심 산출물이다.

---

## 6. rosbridge 소스 자격 판정 (별도 10분 게이트, D-경로와 독립)

Native 경로 진단과 별개로, rosbridge를 평가 파이프라인 데이터 소스로 쓸 수 있는지 판정한다.

```bash
# rosbridge 기동 후 (run_rosbridge.sh), Ego 상태 토픽의 주파수/지연 실측
timeout 30 ros2 topic hz /Ego_topic | tee /tmp/rb_hz.txt
python3 ~/avstack-control/scripts/offset_probe.py   # 기존 자산: 지연/offset 측정
```

| 기준 | 판정 |
|---|---|
| 필요 주파수(잠정 50Hz) 대비 90% 이상 + 지연 안정 | 파이프라인 보조 소스 후보 유지 |
| 미달 | **진단 도구로 격하** (ADR 등재). header.seq 패치는 진단 편의 목적으로만 투자 |

---

## 7. 기록 반영

- 각 D-테스트 종료 시: `commands.tsv`에 명령·evidence 경로 1행
- 진단 완료 시: `issues.tsv` AVS-007에 AMEND 행 (귀속 결과 + 매트릭스 행 명시)
- 귀속이 환경 설정이면: env 변경을 ADR로 (직접 수정 전 결정 기록)
- rosbridge 격하 시: ADR 등재 + 설계노트 9.4(3원 소스) erratum
- MORAI 문의 초안(avs-007_morai_inquiry.md)에 D1/D4 실측 결과 첨부 — "participant 수준부터 확인했다"는 근거는 벤더 대응 속도를 크게 높인다

---

## 8. Claude Code 투입 프롬프트

```text
runbooks/avs-007_layer_diagnosis.md 를 읽고 Stage 05 계층 분리 진단을 준비한다.
이번 작업은 스크립트 준비까지다. 실행은 내가 SIM을 켠 상태에서 직접 한다.

작업:
1. scripts/avs007_diag/ 에 다음을 작성해라:
   - d1_dds_participant.sh: 문서 4장 D1 절차 그대로. sudo tcpdump 부분은
     실행 전 확인 프롬프트를 넣어라.
   - d2_domain_rmw.sh: SIM_DOMAIN_ID를 인자로 받아 문서의 4조합을 순차 실행,
     각 결과를 /tmp/d2_*.txt와 stdout에 기록. 조합당 daemon stop 포함.
   - d3_qos_probe.sh: 토픽명 인자로 받아 info -v → QoS 맞춘 echo --once → hz 15초.
   - d4_lazy_publisher.sh: 더미 구독자 60초 백그라운드 + 목록/hz 확인 + 종료 후 재확인.
   - run_all_diag.sh: D1→D2→D3→D4 순차 실행하되, 문서 4장의 중지 조건에 따라
     하위 계층 FAIL 시 즉시 종료하고 판정 매트릭스의 해당 행을 출력.
     전체를 ~/avstack/runs/avs007_diag_$(date).log 로 tee.
2. 각 스크립트 상단에 해당 테스트의 가설과 판정 기준을 주석으로 넣어라
   (실행자가 문서 없이도 판정 가능하도록).
3. runbooks/avs-007_layer_diagnosis.md 의 3장 사전 조건을 체크리스트로 출력하는
   preflight.sh 를 추가해라. rosbridge 잔존 프로세스 검사 포함.
4. 커밋: "diag: scaffold avs-007 layer-separation diagnosis scripts"

제약:
- 시스템 상태를 바꾸는 명령(apt 설치, env 파일 수정, .bashrc)은 스크립트에 넣지 마라.
  rmw_fastrtps 미설치 감지 시 설치 안내 메시지만 출력해라.
- 진단 결과의 TSV 기록은 실행 후 내가 결과를 보여주면 그때 함께 한다.
```

---

*본 진단의 산출물은 "고쳐진 시스템"이 아니라 "귀속이 확정된 이슈"다. 귀속 확정 후의 수정 작업은 별도 실험 카드로 진행한다.*

---

## 부록 A — 이 환경과의 정합 노트 (2026-07-04, 실측 대조)

본문은 정본으로 유지하되, 스크립트 구현 시 아래 실측값을 적용했다(디버깅 규칙: 실물 먼저·모순 잔존 금지).

| 본문 전제 | 이 환경의 실물 | 스크립트 적용 |
|---|---|---|
| `env/ros2_humble.env` (DOMAIN=42, CycloneDDS) | 해당 파일 없음. 실물은 `scripts/stage05_ros2_native/env.sh` (**DOMAIN=0, rmw_fastrtps_cpp**) | env.sh 소싱, 기준선=(0, fastrtps). D2는 2×2 (DOMAIN {0, SIM_UI값} × RMW {fastrtps, cyclonedds}) |
| 호스트 기준 CycloneDDS | SIM Plugins typesupport=fastrtps 303/0 → 기준 RMW=fastrtps (2026-07-03 실측). cyclonedds는 설치돼 있어 D2 교차검증에 사용 | H2b는 "fastrtps↔cyclonedds 교차" 그대로 검증 가능 |
| `scripts/offset_probe.py`, `scripts/send_ctrl_cmd.sh` | 실경로 `scripts/stage05_ros2_native/…` | 실경로 사용 |
| `commands.tsv` | 저장소에 없음(기록수단: stages/issues/decisions.tsv) | 기록은 issues.tsv AMEND + evidence 로그로 갈음(신설 여부는 사용자 결정) |
| 사전조건 "SIM ROS2 Native 활성화" | 2026-07-03 실측: launcher 기본(ROS2 미소싱)에서 ROS2 Connect 시 ros2cs NativeRcl 예외로 Disconnect. **그 상태 그대로가 D1의 검증 대상**(participant 생성 여부) | D1은 이 상태에서 관찰. `SOURCE_ROS2=1`은 SIM startup 사망(AVS-007)이므로 사용 금지 |
| §6 rosbridge 게이트의 hz 실측 | header.seq 거부로 현재 데이터 0 → 패치 전에는 hz 측정 불가 | §6은 **header.seq 처리 후에만 유의미**. 게이트 판정을 패치 이후로 순서 조정 |
