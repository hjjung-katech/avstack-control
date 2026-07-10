# AVStack Control

> 세션 시작 시 PROJECT_STATUS.md 를 먼저 읽고, 종료 시 갱신한다 (8장 인수인계 규약).

MORAI SIM + Scenario Runner + ROS2 Humble + Autoware 연동 환경 구축 프로젝트.
이 저장소(~/avstack-control)는 Git 관리 대상이며, 실행 데이터는 ~/avstack(Git 제외)에 있다.

## 환경
- Host: t15p-dev-ubt / Ubuntu 22.04.5 / NoMachine X11 원격
- GPU: RTX 3050 Laptop 4GB, PRIME on-demand, driver 580.159.03
- 기본 OpenGL은 Intel이므로 MORAI 계열 실행 시 NVIDIA offload 필수

## 운영 규칙
- Gate 기반 진행: 현재 Stage 통과 기준을 만족하기 전에 다음 Stage 작업을 하지 않는다.
- MORAI Launcher/SIM/Scenario Runner는 scripts/run_morai_launcher_nvidia.sh로만 실행한다.
- 기록은 TSV를 직접 수정하지 말고 반드시 스크립트로 한다:
  - Stage:    scripts/record_stage.sh <stage> <PASS|FAIL> "<요약>" "<로그경로>" "<다음>"
  - Issue:    scripts/record_issue.sh <ID> <stage> <OPEN|RESOLVED> <HIGH|MED|LOW> "<증상>" ...
  - Decision: scripts/record_decision.sh <ADR-ID> ACCEPTED "<결정>" "<이유>"
- 터미널 증거는 script 명령으로 ~/avstack/runs에 저장하고 TSV에는 경로만 남긴다.
- Markdown 문서는 runbooks/ 또는 명시 요청이 있을 때만 작성한다.
- ros2 topic echo는 --once 또는 timeout 5와 함께만 실행한다.
- Docker와 Autoware 설치 작업은 Stage 05 통과 전까지 보류한다.
- Stage 03.7(경계 감지) 통과 전에는 Batch 파이프라인(05.5) 구축을 시작하지 않는다.
- Stage 05.7 통과 전에는 Autoware/Docker 작업을 시작하지 않는다.
- TSV는 append-only. 과거 행 정정은 AMEND: 접두어를 단 새 행 추가로 하며, 동일 stage/id에 행이 여러 개면 최신 행이 유효하다.
- 벤더 커뮤니케이션 상태 전이(DRAFT/SENT/ANSWERED 등)는 records/vendor_comms.tsv에 `AMEND:` 접두 새 행으로 append한다(동일 comm_id 최신 행이 유효). in-place 편집 금지.
- vendor/*/OUTBOX 초안의 발송 금지 내용(제목 아래 안내문·"내부 추적용" 경로·스레드 분리 주석 등)은 `<!-- INTERNAL: ... -->` 로 감싸고, SENT 동결 시 이 블록을 제거한 발송본을 저장한다.
- 문의에 인용된 증거는 발송 전 vendor/<사>/evidence/ 에 사본을 동결한다(대외 주장의 근거는 git 관리 영역에 있어야 한다).

## 디버깅 규칙 (미지/벤더 서브시스템 — AVS-007 회고에서 도출)
- 실물 먼저: 결론·변경 전에 실물(메타데이터/`.so` 의존성/버전/원본 로그)을 조사한다. 파일명·외부 문서·확장자만으로 메커니즘을 단정하지 않는다.
- 사실/추론 분리: 진단은 "관측(사실)"과 "해석(추론)"을 구분해 적는다. 추론을 사실처럼 다루는 것이 논리 비약이다.
- 가설엔 반증 테스트: 조치 전에 [가설/뒷받침 관측/반증할 값싼 테스트]를 명시한다. 반증 테스트가 없으면 조치하지 않는다.
- 값싼 검증 먼저: 사람/GUI(SIM) 재기동이 필요한 변경 전에, SIM 없이 되는 정적 검증(ldd/dlopen, rclpy 재현, /proc)을 먼저 소진한다.
- 원본 로그: 잘린/중계 로그(/rosout 등)로 결론내지 않는다. 실패 프로세스의 원본 stderr/터미널을 확보한다.
- 뒤집히면 일괄 정정: 진단이 반전되면 이전 서술을 남기지 말고 관련 문서·스크립트·기본값을 같은 커밋에서 일괄 정정한다(모순 잔존 금지).

## 저장소 경계 (정본: runbooks/repo_boundaries.md, ADR-011)
- 5리포(별칭): **[SCEN]** oss3-scenarios(정의) → **[WS]** ~/avstack(실행·재생성물, **non-git**) → **[EVAL]** avstack-eval(평가 프레임워크 코드) → **[CONTROL]** avstack-control(판정 원장·절차·도구 정본, 본 리포) → **[MGMT]** oss3-mgmt(요약·계획). "정의는 git, 재생성물은 밖." 관리 리포 참조는 **[MGMT]**로 표기.
- **[CONTROL] 안에 stages/·runbooks 판정본/·issues 같은 별도 판정 폴더를 만들지 않는다.** 스테이지·이슈·결정 판정은 `records/*.tsv`가 유일 권위(특히 판정은 `stages.tsv` 단일).
- [WS] 및 STATUS 류 문서는 판정을 자체 보유하지 말고 `stages.tsv`를 포인터로 참조한다(AVS-008).

## Stage 현황 (Gate 통과 시 이 섹션을 갱신하고 stage 기록과 함께 커밋)
- 00 Remote GPU: PASS
- 01 MORAI Launcher/SIM: PASS
- 02 Scenario Runner Window: PASS
- 03 Example XOSC Built-in: PASS (KATRI+Cut_In_1, Built-in ego 주행 확인. SR GUI는 검게 렌더돼 블라인드 조작 — AVS-004)
- **다음: 03.5 Python API 계약 검증** — **BLOCKED (AVS-006)**. 실물 API=OpenSCENARIO API 22.R3(`~/avstack/morai/scenario_runner`), Python 3.7.3 env(miniconda morai-osc) 구성 완료. sourcedefender 3.7 런타임 확보 불가로 보류(MORAI 문의 대기). AVS-001 RESOLVED.
- 03.7 API 단일 실행 + 경계 감지: TODO (**게이트**)
- 04 ROS2 Humble Host: PASS (desktop 273 pkg, talker→/chatter echo --once 수신, RMW=fastrtps, ROS_LOCALHOST_ONLY=0)
- 05 MORAI ROS2 Native Topic: **BLOCKED (AVS-007)** — native·rosbridge 양 경로 모두 차단. 벤더 1차 회신(2026-07-08) 진단 "morai_msgs 미소싱"은 **T-24 검증(2026-07-10)으로 반증**: 26.R1 태그 오버레이 소싱(environ 실물 증거) 상태에서 native std::bad_cast 동일 재현 + rosbridge header.seq 거부 138,841건(15분 누계, 표준 tf 포함)·역방향 무반응 — 매트릭스 4/4 FAIL, 분기 C. **재회신 초안 검토 대기**(vendor/morai/OUTBOX/MORAI-001_avs007_t24_followup.md, 증거 동결 완료). 검증 정본: runbooks/t24_vendor_diag_verification.md.
- 05.5 Built-in Batch 파이프라인: TODO (**Autoware 전 필수**)
- 05.7 재현성 캘리브레이션 + Multi-Map: TODO
- 06~08 Autoware/Mapping/Closed-loop: 보류 (05.7 통과 후)
- 통합 로드맵 정본: runbooks/integrated_roadmap.md (ADR-007)

## 열린 이슈 (해결 시 이 섹션과 issues.tsv를 함께 갱신)
- AVS-002: OPEN(MED) — 대형 지도 로드 시 SIM 크래시. `sangam_nobuilding`(686MB) 로드 중 Vulkan Out of memory→SIGSEGV. **4GB VRAM 부족**(K-City 350MB는 정상). 완화: 4GB에 맞는 지도 사용. (※ 이전 "부분 렌더/GPU 성능" 진단은 증상 오해로 정정됨)
- AVS-001: RESOLVED — SR 창 미표시는 libxcb-xinerama0 + liblapack3/libblas3 누락. 설치 후 SIM 경유로 정상. SR 단독 로그인은 계정 ID 필요(OPEN-05).
- AVS-003: RESOLVED — MORAISim.sh exit 127(백틱)·SingleInstance 양보-exit0. 래퍼에서 흡수·가드.
- AVS-004: OPEN(MED) — Scenario Runner VTK/OpenGL GUI가 이 X 환경(NoMachine+offload)에서 검게 렌더(호버 시만 깜박). 소프트웨어 GL·QT_XCB_GL_INTEGRATION=none·SIM 끔 모두 무효 → 렌더 경로 문제. 완화: 블라인드 조작 + SIM에서 결과 확인.
- AVS-005: OPEN(LOW) — MORAI SIM 창을 리사이즈/축소하면 hang/크래시(swapchain 재초기화 폭주). 완화: SIM 창 크기 건드리지 말 것.
- AVS-006: OPEN(HIGH) — OpenSCENARIO API 22.R3 lib이 sourcedefender 암호화(.pye 694개)인데, 3.7용 sourcedefender 런타임이 PyPI에서 삭제돼(현재 8개 릴리스 전부 >=3.9/3.10) API import 불가 → **Stage 03.5 블로커**. env(py3.7.3)는 준비됨. 대응: MORAI에 정확한 sourcedefender 버전/설치 경로 문의. (증거: ~/avstack/logs/avs006_*)
- AVS-007: OPEN(HIGH) — **Stage 05 블로커, native·rosbridge 양 경로 차단**. (1) native ros2cs(standalone=0, humble 2023-03-31): host Humble(2026) SIM startup시 `librmw_fastrtps_cpp std::bad_cast`. **H1(버전정합) 반증**에 이어 **벤더 진단(msgs 미소싱)도 T-24로 반증**(2026-07-10: 26.R1 오버레이 소싱 environ 증거 상태에서 동일 크래시 — bad_cast는 rcl/rmw 초기화 계층, msgs와 무관). (2) rosbridge: 연결·토픽생성 OK지만 SIM publish 전량 거부 — 26.R1 정합 msgs로도 `header.seq` 거부 138,841건(15분 누계, 9타입, 표준 `tf2_msgs` 포함), CtrlCmd 역방향 무반응. 원인은 SIM 측(ROS1 헤더 포맷 발행/rmw 로드 실패). 대응: **재회신**(검증 환경 정보·호환 버전 조합·standalone ros2cs·ROS2 포맷 옵션 요청) — 초안 vendor/morai/OUTBOX/MORAI-001_avs007_t24_followup.md, 증거 vendor/morai/evidence/avs007_t24_20260710_*. (검증 정본 runbooks/t24_vendor_diag_verification.md, 리포트 runbooks/avs-007_ros2_native_report.md)

## 커밋 규칙
- 커밋 시점: Stage 통과, 이슈 등록/해결, 스크립트·설정 변경 시에만.
- 메시지는 소문자 영어 한 줄: 예) stage01 morai launcher pass / resolve AVS-001

## 금지
- ~/avstack/morai 바이너리 수정 금지
- ROS_LOCALHOST_ONLY=1 설정 금지
- prime-select 변경, 드라이버 재설치, sudo 설치는 사용자 확인 후에만
- 라이선스/토큰/계정 파일 읽기 금지. 로그 분석 전 다음으로 민감정보 확인:
  grep -i -E "token|license|auth|password|key|secret" <logfile>

## 세션 시작 시
- /memory로 이 파일 로드 확인 후, records/stages.tsv와 issues.tsv를 읽고 현재 위치를 파악한다.