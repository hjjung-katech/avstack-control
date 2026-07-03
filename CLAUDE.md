# AVStack Control

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

## Stage 현황 (Gate 통과 시 이 섹션을 갱신하고 stage 기록과 함께 커밋)
- 00 Remote GPU: PASS
- 01 MORAI Launcher/SIM: PASS
- 02 Scenario Runner Window: PASS
- 03 Example XOSC Built-in: PASS (KATRI+Cut_In_1, Built-in ego 주행 확인. SR GUI는 검게 렌더돼 블라인드 조작 — AVS-004)
- **다음: 03.5 Python API 계약 검증** — **BLOCKED (AVS-006)**. 실물 API=OpenSCENARIO API 22.R3(`~/avstack/morai/scenario_runner`), Python 3.7.3 env(miniconda morai-osc) 구성 완료. sourcedefender 3.7 런타임 확보 불가로 보류(MORAI 문의 대기). AVS-001 RESOLVED.
- 03.7 API 단일 실행 + 경계 감지: TODO (**게이트**)
- 04 ROS2 Humble Host: PASS (desktop 273 pkg, talker→/chatter echo --once 수신, RMW=fastrtps, ROS_LOCALHOST_ONLY=0)
- 05 MORAI ROS2 Native Topic: TODO ← 다음 (04 완료)
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