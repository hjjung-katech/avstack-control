# MORAI SIM 연동 이슈 2건 해결 보고 (2026-07-10) — [MGMT] 반영용 브리프

## 1. 요약 (3줄)

- 크리티컬 패스를 막던 벤더 의존 이슈 2건 — **AVS-006(Python API 실행 불가)·AVS-007(ROS2 연동 불가)** — 이 **2026-07-10 하루에 모두 해결**됐다.
- AVS-007의 근본원인은 벤더 1차 진단("morai_msgs 미소싱")이 아니라 **우리 실행 스크립트가 설정하던 `RMW_IMPLEMENTATION` 환경변수**였다. 자체 검증(T-24/T-25, 1-변수 대조 실험)으로 규명했고, ROS2 native **수신 50.2Hz + 차량 제어(왕복)까지 실측** — **Stage 05 PASS**.
- AVS-006은 벤더가 약속 기한(7/10)에 **Python 3.13 재빌드 API를 납품** → 신규 env에서 import 검증 완료 — **Stage 03.5 재개 가능**.

## 2. 경위 (하루 타임라인)

| 시각 | 사건 |
|---|---|
| 오전 | **T-24 매트릭스**: 벤더 1차 진단("msgs 미소싱") 검증 — 소싱을 실물 증거(SIM 프로세스 environ)로 입증한 상태에서 native 크래시·rosbridge 거부(표준 tf 포함 138,841건) **동일 재현** → 진단 반증, 증거 패키지(기술상세 PDF+로그 zip)로 재회신 발송 |
| 정오 | **벤더 2차 회신 수신**: 자사 환경 정보 공개 + "소싱 후 런처 직접 실행" 재확인 요청 + **rosbridge는 ROS2 공식 경로 아님** 확인 + **API py3.13 재빌드 납품** |
| 오후 | **T-25**: 벤더 방식으로 실행 → SIM 정상, ROS2 Connect 후 토픽 18종·50.2Hz 수신. 1-변수 대조(N4)로 **크래시 트리거 = `RMW_IMPLEMENTATION` 환경변수 확정**(설정 시에만 크래시 재현). 3국면 판별(중력 크리프/설정창 동결/명령-움직임 시간상관)로 **차량 제어 확정** → **Stage 05 PASS, AVS-007 RESOLVED** |
| 오후 | **AVS-006 검증**: py3.13 env(conda-forge) + sourcedefender 16.0.65 → 암호화 `.pye` 252개 **import 성공**, API 생명주기 표면 확인 → **RESOLVED** |
| 저녁 | **3차 회신(해결 보고 2건 통합) 발송** — 벤더 커뮤니케이션 3왕복으로 두 트랙 종결 |

## 3. 스테이지/이슈 현황 (원장: [CONTROL] records/*.tsv)

| 항목 | 이전(오늘 아침) | 현재 |
|---|---|---|
| Stage 03.5 (Python API) | BLOCKED (AVS-006) | **재개 가능** — import·API 표면 검증 완료, SIM 연동 실행만 남음 |
| Stage 05 (ROS2 Native) | BLOCKED (AVS-007) | **PASS** — 수신 50.2Hz + CtrlCmd 제어 실측 |
| AVS-006 | OPEN(HIGH) | **RESOLVED** — py3.13 재빌드 + sourcedefender 현행판 |
| AVS-007 | OPEN(HIGH) | **RESOLVED** — 원인=RMW_IMPLEMENTATION 변수, 래퍼 정정 완료 |
| 벤더 문의(MORAI-001/002) | 회신 대기 | **종결** — 3왕복(문의→진단→검증반증→환경공개→해결) |

## 4. [MGMT] 항목별 반영안

- **SIM-05 (ROS2 연동)**: 상태 **해결**로 변경. 판정 근거는 [CONTROL] `records/stages.tsv`(05 PASS, 2026-07-10) 포인터 참조.
- **TECH-03 / TECH-14 / TECH-25**: "ROS2 연동 불가/벤더 의존 차단"을 전제하던 항목은 전제 해소로 상태 갱신(재개/종결). 세부 판단은 각 항목 내용 대조 후 — 근거 정본은 `runbooks/t24_vendor_diag_verification.md` §6.
- **kb/morai/observed 추가 (4건)**:
  1. **`RMW_IMPLEMENTATION` 설정 시 SIM(ros2cs) startup 크래시** — rcl rmw identifier 검사 경로의 std::bad_cast. 미설정이 정상. SIM용 환경에서 이 변수를 설정하지 말 것.
  2. **SIM 설정창(센서 등) 열림 = 물리 일시정지** — 토픽은 마지막 값을 계속 발행하므로 원격 관측만으로는 "무반응"과 구분 불가. 실험 전제 = 창 전부 닫힘.
  3. **rosbridge(ROS 모드)는 ROS2 공식 경로 아님**(벤더 확인) — SIM이 ROS1 헤더(seq) 포맷 발행. ROS2는 native 단일 경로.
  4. **ROS2 native 운영 요령** — 토픽 타입은 `morai_ros2_msgs`(공식 리포 main 빌드), 외부 제어는 `/multi_ego_setting`(ctrl_mode=16 auto, gear=4 D) 후 `/ctrl_cmd`(velocity 모드 추종 실측). 서비스 없음(topic 전용). **GRPC 7789 = OpenSCENARIO API 채널**(ROS2와 별개).

## 5. 다음 계획 / 리스크

1. **Stage 03.5 실행**(다음 GUI 세션): SIM + GRPC Connect(7789) 상태에서 example xosc를 재빌드 API로 실행 → 계약 검증 → **03.7(경계 감지) 게이트** — API에 `get_stop_status`/stop 콜백이 있어 재료 확보됨 → 이후 05.5 Batch 파이프라인.
2. **ADR-009 재검토**: "무인 데이터 경로에서 ROS2 Native 제외" 전제가 Stage 05 개통으로 변경 후보 — ADR 갱신 여부 결정.
3. **리스크**: ① 재빌드 API의 SIM 연동 실행은 미검증(import까지 확인) — 03.5에서 확인. ② RMW 변수 이슈의 벤더측 수정(변수 무시/안내) 여부 미정 — 3차 회신에 개발팀 전달 제안함. ③ 구 py3.7 env·22.R3 API 폐기 예정(전환 완료 후).

## 6. 증거/기록 포인터 ([CONTROL] = avstack-control)

- 검증 정본: `runbooks/t24_vendor_diag_verification.md` v2.0 (§3 T-24 매트릭스, §6 T-25·동작 레시피)
- 원장: `records/stages.tsv`(05 PASS) · `records/issues.tsv`(AVS-006/007 RESOLVED) · `records/vendor_comms.tsv`(3왕복 전이) · `records/commands.tsv`(실측 8행)
- 벤더 왕복: `vendor/morai/{SENT,INBOX}/2026070*` (발송 동결본·회신 전문) · 증거 동결 `vendor/morai/evidence/avs007_t24_20260710_*`
- 재현성: `environment-morai-osc-py313.yml` · 래퍼 `scripts/run_morai_launcher_nvidia.sh`(정정판) · 판별 스크립트 `scripts/recheck/t25_ctrl_verify.sh`
- 오늘 커밋: `893b1d7`→`ed9010f` (main, 푸시 완료) · 세션 상세: `reports/2026-07-10_session.md`
