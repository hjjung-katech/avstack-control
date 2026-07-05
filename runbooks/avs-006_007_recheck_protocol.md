# AVS-006/007 재검증 실험 프로토콜 (발송 전 증거 확정)

| 항목 | 내용 |
|---|---|
| 문서명 | MORAI 문의 발송 전 재검증 실험 프로토콜 |
| 버전 | v1.0 |
| 작성일 | 2026-07-05 |
| 위치 | `~/avstack-control/runbooks/avs-006_007_recheck_protocol.md` |
| 목적 | MORAI-001/002 문의의 재현 횟수·증거를 실측으로 확정 (기억 의존 제거) |
| 부수 효과 | E2 실행 중 D1(DDS participant) 진단 데이터 동시 확보 |

---

## 1. 실험 목적과 설계 원칙

**목적**: 문의문 §3의 `[사용자 기입: N회 시도]`를 기억이 아닌 **오늘 날짜의 통제된 재현 N=3**으로 대체하고, 증거를 최신 timestamp로 갱신한다.

**설계 원칙**

- **N=3 고정**: 결정론적 실패에서 3회 동일 재현이면 통계적 추가 가치가 없다. 3회를 넘기지 않는다 (시간 낭비 방지).
- **"동일 재현"의 정의를 사전 선언**: 각 실험 카드에 동일성 판정 기준(예외 문자열, 종료 거동, 로그 시그니처)을 명시한다. 3회 중 1회라도 다르면 "결정론적"이라는 문의 문구를 수정해야 하므로, 이 자체가 검증이다.
- **회차 간 상태 초기화**: 각 회차는 독립이어야 한다. 초기화 절차를 카드에 명시.
- **증거 파일명 규칙**: `avs00X_recheck_20260705_run{N}_{내용}.{ext}` — 회차 귀속이 파일명으로 확정.
- **겸용 최대화**: E2(Native crash)는 D1 진단의 관찰 창이기도 하다. tcpdump를 상시 물려 한 번의 클릭으로 두 데이터를 얻는다.

**실행 환경 구분**

| 실험 | 장소 | SIM 필요 | 예상 시간 |
|---|---|---|---|
| E1 (sourcedefender) | 원격 가능 | 불필요 | ~10분 |
| E2 (ROS2 Native crash) | **PC 앞** (매회 GUI 재시작) | 필요 | ~20분 |
| E3 (rosbridge 데이터 0) | PC 앞 (원격+1분 세팅도 가능) | 필요 | ~15분 |

---

## 2. E1 — sourcedefender 설치 실패 재검증 (MORAI-002 §3)

**가설**: `pip install sourcedefender`는 python 3.7.3 환경에서 결정론적으로 실패한다 (3.7 호환 배포 부재).

**동일성 판정 기준**: 3회 모두 ① "Ignored versions requiring different python" 계열 오류 ② "No matching distribution found" ③ 설치된 패키지 없음.

**절차** (각 회차, `morai-osc` conda 환경에서)

```bash
RUN=1  # 2, 3 반복
LOG=~/avstack/logs/avs006_recheck_20260705_run${RUN}.log
{
  echo "=== RUN ${RUN} $(date -Is) ==="
  python --version; pip --version
  pip cache purge                          # 회차 간 초기화: 캐시 배제
  pip install sourcedefender; echo "exit=$?"
  pip index versions sourcedefender; echo "exit=$?"
  pip list | grep -i sourcedefender || echo "not installed"
} 2>&1 | tee "$LOG"
```

**1회만 추가**: PyPI 실태 스냅샷 갱신 (문의 §4의 날짜를 오늘로)

```bash
curl -s https://pypi.org/pypi/sourcedefender/json | python -m json.tool \
  > ~/avstack/logs/avs006_recheck_20260705_pypi_snapshot.json
# releases 키 목록과 각 requires_python 확인
```

**PASS**: 3회 동일 → MORAI-002 §3에 "3회 재현 (2026-07-05)" 기입, §4 PyPI 조회일 갱신.
**이상 시**: 어느 회차든 다른 결과(예: 설치 성공)가 나오면 **발송 중지** — AVS-006 자체를 재검토 (PyPI에 3.7 지원 버전이 복귀했을 가능성).

---

## 3. E2 — ROS2 Native Connect 크래시 재검증 (MORAI-001 §3-A + D1 겸용)

**가설 (2중)**
- H-a: host ROS2(Humble) 소싱 상태에서 Network Settings ROS2 Connect 시 SIM이 `librmw_fastrtps_cpp std::bad_cast`로 즉시 종료한다 (3회 결정론적).
- H-b (D1 겸용): 종료 시점까지 SIM 프로세스는 DDS participant를 생성하지 못한다 (RTPS discovery 패킷 0).

**동일성 판정 기준**: 3회 모두 ① Connect 후 SIM 프로세스 소멸 ② Player.log에 `std::bad_cast` + `librmw_fastrtps_cpp` 문자열 ③ tcpdump에 SIM 발신 RTPS 패킷 없음.

**사전 조건**: rosbridge 등 브리지 프로세스 전무 (`pgrep -af rosbridge` 공란), ros2 daemon stop, 호스트 env는 표준(`ros2_humble.env`) 소싱.

**절차** (각 회차 — SIM이 매회 죽으므로 회차마다 GUI 재기동 필요)

```bash
RUN=1  # 2, 3 반복
BASE=~/avstack/logs/avs007_recheck_20260705_run${RUN}

# [터미널 1] 관찰 시작 (Connect 클릭 전에)
sudo tcpdump -i any udp portrange 7400-7500 -nn -w ${BASE}_rtps.pcap &
TCPDUMP_PID=$!
pgrep -f -i "morai|simulator" | tee ${BASE}_simpid_before.txt

# [GUI] 런처 → 지도 로드 → Start → Network Settings → ROS2 → Connect
#       (여기가 사람 클릭. 클릭 직전 시각을 소리내어 기록: date -Is)

# [터미널 1] SIM 종료 확인 후 (~10초 대기)
pgrep -f -i "morai|simulator" | tee ${BASE}_simpid_after.txt   # 공란 기대
sudo kill $TCPDUMP_PID
cp ~/.config/unity3d/MORAI/*/Player.log ${BASE}_player.log 2>/dev/null \
  || find ~ -name "Player.log" -newer ${BASE}_simpid_before.txt -exec cp {} ${BASE}_player.log \;
grep -n "bad_cast\|rmw\|ros2cs" ${BASE}_player.log | head -30
tcpdump -r ${BASE}_rtps.pcap 2>/dev/null | head -20   # SIM 발신 패킷 유무
```

**PASS**: 3회 동일 크래시 + 3회 모두 RTPS 무발신 →
- MORAI-001 §3-A에 "3회 재현 (2026-07-05)" 기입
- **D1 판정 = FAIL(participant 미생성) 확정** → 진단 매트릭스 1행(벤더 귀속), MORAI-001 §4에 "DDS 계층 실측: Connect~종료 구간 RTPS discovery 패킷 0 (pcap 첨부 가능)" 1줄 보강 — 이 한 줄이 문의의 설득력을 크게 높인다.

**이상 시**: 크래시가 재현되지 않으면 발송 중지, AVS-007 재검토 (환경 변화 확인). RTPS 패킷이 관측되면 D1=PASS로 기록하고 D2 이후 진단으로 연결 (문의 문구는 유지 가능 — 크래시 자체는 사실).

---

## 4. E3 — rosbridge 데이터 0 재검증 (MORAI-001 §3-B)

**가설**: rosbridge 경로는 연결·토픽 생성은 되나 header.seq 거부로 수신 데이터가 0이다 (3회 결정론적).

**동일성 판정 기준**: 3회 모두 ① rosbridge 연결 성공 ② 토픽 생성 확인 ③ echo 수신 0건 ④ rosbridge_server 로그에 header/seq 거부 메시지.

**사전 조건**: E2와 분리 실행 (Native Connect 시도 금지 — SIM이 죽는다). SIM은 살아있는 상태 유지. **회차 간 초기화**: rosbridge_server 재시작 + SIM 쪽 Disconnect/재Connect + `ros2 daemon stop` — client_count 누적 오염 방지가 핵심.

**절차** (각 회차)

```bash
RUN=1
BASE=~/avstack/logs/avs007b_recheck_20260705_run${RUN}

# [터미널 1] rosbridge 기동 (기존 스크립트 재사용)
~/avstack-control/scripts/run_rosbridge.sh 2>&1 | tee ${BASE}_rosbridge.log &

# [GUI] SIM Network Settings: Simulator/Ego/Sensor → ROS 127.0.0.1:9090 Connect

# [터미널 2]
ros2 topic list | tee ${BASE}_topics.txt
timeout 15 ros2 topic echo /Ego_topic --qos-reliability best_effort \
  | tee ${BASE}_echo.txt                       # 0건 기대
grep -c "seq" ${BASE}_rosbridge.log            # 거부 로그 카운트

# 회차 종료: SIM Disconnect → rosbridge kill → ros2 daemon stop
```

**PASS**: 3회 동일 → MORAI-001 §3-B에 "3회 재현 (2026-07-05)" 기입.
**참고**: rosbridge 소스 자격 게이트(hz 측정)는 데이터가 0이므로 이 상태에서는 실행 불가 — header.seq 해소 후로 명시 이연.

---

## 5. 결과 반영 절차 (실험 → 문의·기록)

1. **문의문 갱신**: MORAI-001 §3-A/B, MORAI-002 §3의 `[사용자 기입]` → "3회 재현 (2026-07-05)". MORAI-002 §4 PyPI 조회일 갱신. E2에서 D1 확정 시 MORAI-001 §4에 RTPS 실측 1줄 추가.
2. **증거 동결**: 회차 로그 대표본(run1)과 pcap·PyPI 스냅샷을 `vendor/morai/evidence/`에 사본 동결 (§4.2 규약).
3. **원장 기록**: commands.tsv에 실험별 1행, issues.tsv AVS-007에 AMEND 행(D1 결과 반영 시), stages.tsv 불변 (Stage 상태 변화 없음).
4. **진단 계획 연동**: E2의 D1 결과를 `avs-007_layer_diagnosis.md` 판정 매트릭스에 기입 — D1=FAIL이면 D2~D4는 "불필요(하위 계층 확정)"로 종결 처리, D5(제어 역방향)만 별도 가치 판단.
5. 이후 발송 → 프롬프트 A(SENT 동결)로.

---

## 6. Claude Code 투입 프롬프트

```text
runbooks/avs-006_007_recheck_protocol.md 를 읽고 재검증 실험을 준비·실행한다.
GUI 클릭(런처 Start, Network Settings Connect)은 내가 한다. E1은 네가 자율
실행 가능, E2/E3는 내 클릭 신호와 인터리브로 진행한다.

1. E1을 3회 실행하고 (문서 2장 절차 그대로, 회차별 로그 저장 + PyPI 스냅샷),
   동일성 판정 기준으로 PASS/이상 여부를 보고해라. 이상 시 즉시 멈추고 보고.
2. E2: 회차별 관찰 스크립트(tcpdump 시작/종료, PID 기록, Player.log 수집,
   시그니처 grep)를 scripts/recheck/e2_observe.sh 로 만들고, 내가 GUI를
   조작할 타이밍을 단계별로 안내해라. 3회 완료 후 H-a/H-b 판정.
3. E3: 동일하게 scripts/recheck/e3_observe.sh + 회차 간 초기화(rosbridge
   재시작, daemon stop) 포함. 3회 완료 후 판정.
4. 판정이 모두 PASS면 문서 5장대로: 문의문 [사용자 기입] 갱신(diff 승인),
   evidence 동결, commands.tsv 기록, AVS-007 AMEND(D1 결과), 진단 매트릭스
   기입. 하나라도 이상이면 문의문을 건드리지 말고 이상 내용만 보고해라.
5. PROJECT_STATUS 갱신 → 세션 리포트 → 커밋·푸시.

제약: sudo tcpdump는 실행 전 나에게 확인. 문의문 §5(질문)·§6(요청)은
이 세션에서 수정 금지 — §3/§4 실측 갱신만.
```

---

*이 실험의 산출물: 문의문의 모든 재현 주장이 "오늘 날짜의 통제된 3회 실측"으로 뒷받침되고, D1 진단이 무료로 확정된다. 발송은 이 직후가 최적이다.*