# Stage 03.5 — Python API 계약 검증 체크리스트

작업 정의: `runbooks/integrated_roadmap.md` 4장. 목적은 Scenario Runner Python API의
실제 동작 계약을 **실측으로 확정**하는 것(문서를 믿지 않고 계약을 실측).

- 선행: Stage 03 PASS (완료)
- 관련 결정: ADR-007(통합 로드맵), ADR-008(프레임워크 별도 저장소)
- 산출물: 저장소 루트 `api_contract.md`, (있으면) 프레임워크 repo `VERSIONS.lock`

---

## 0. step1 확인 결과 + API 획득 방법 (2026-07-03, 재검토 반영)

**로컬 상태**
- 설치본의 Scenario Runner는 **PyInstaller 프리즈 바이너리**뿐:
  `.../ScenarioRunner/scenario_runner_v1.7.0_linux/{runner, program/Scenario Runner, program/_internal/}`.
- **API import 모듈·`.whl`·pip 패키지 없음.** `~/avstack/morai/scenario_runner`, `~/avstack/morai/sim`은
  **빈 placeholder 디렉터리**(API 미배치). grpcio도 미설치.

**문서 확인 (help-morai-sim.scrollhelp.site)**
- Stage 03.5 대상 = **Scenario Runner Python API** (`OpenScenarioClientAPI`), gRPC `localhost:7789`.
  생성자: `OpenScenarioClientAPI(host="127.0.0.1", port="7789", user_start_callback_func=None, user_stop_callback_func=None)` (port는 **문자열**).
  메서드: `is_connected()`, `get_simulator_version()`, `get_available_map()`, `set_scenario_config(...)`, `start_batch_scenario()`.
- 이는 **SIM API**(`MoraiSimClient`, UDP/gRPC, ego/센서 제어)와 **다른 API**다. SIM API 예제 저장소
  (github.com/MORAI-Autonomous/MORAI-DriveExample_GRPC, grpc-docs)는 참조용이며 SR API의 대체가 아니다.

**획득 경로 (택1)**
- **경로 A (권장)**: MORAI 다운로드 포털/계정에서 **OpenSCENARIO API 예제 패키지 zip**을 받아 압축해제 →
  `lib/` 폴더(암호화된 MORAI OpenSCENARIO 라이브러리)를 포함. `~/avstack/morai/scenario_runner`에 배치.
  - 다운로드 파일명 예: `OpenSCENARIO_API_Linux.zip`(22.R2), `OpenSCENARIO_API_22.R3.zip` →
    **설치된 Drive가 26.R1이므로 26.R1용 대응 zip을 받는다.** (계정·라이선스 게이트 = 사용자 수행)
  - import 원문(문서): `from lib.openscenario.client.open_scenario_client import OpenScenarioClient`
    → 스크립트의 `API_SRC_DIR`은 **압축해제 루트**(그 아래에 `lib/`가 보이도록), `API_MODULE`은 실제 예제 확인 후 확정.
- **경로 B (폴백)**: 패키지를 못 구하면 SR OpenScenario용 `.proto` 확보 → `grpcio-tools`로 스텁 생성 후 7789 직접 통신.
  공개 grpc-docs는 SIM API용이라 SR 계약과 다를 수 있음 → proto 확인 필요.

**의존성 (경로 A, 문서 기준)**
- `grpcio` / `grpcio-tools` — 릴리스별 상이(openscenario-api 페이지 1.39.0, SIM gRPC 페이지 1.44.0). **26.R1 실제값은 패키지 requirements로 확정.**
- `numpy`(1.19.1), `PyQt5`, `matplotlib`, `scipy`, `eventhandler`, `pyproj`
- **암호 해제 런타임 필수**: `sourcedefender`(22.R3+/26.R1) 또는 `pyconcrete`(22.R2). 없으면 암호화 lib import 실패.
- (pip 설치는 사용자 확인 후. CLAUDE.md 규칙 준수.)

**⚠️ 버전 잠금 / 위험**
- 암호화 lib는 **특정 Python 버전에 고정**됨(22.R2/R3=3.7.3). 우리 SR v1.7.0 번들은 cpython-3.10 →
  26.R1 lib은 3.10 가능성. **파이썬 버전 불일치 시 import 실패**하므로, 패키지 requirements의 python 버전을 먼저 확인하고 필요하면 전용 venv 구성.
- **문서 간 API 표면 불일치**: `OpenScenarioClientAPI`(scenario-runner-kr) vs
  `OpenScenarioClient`/`OpenScenarioClientWrapper`+`OpenScenarioImporterWrapper`(openscenario-api).
  어느 것이 26.R1 실물인지는 **다운로드 패키지의 예제 코드로 확정**한다. 스크립트 상단 `CLIENT_CLASS`는 실물에 맞춰 조정.

---

## 1. 실행 전 조건 (preflight)

- [ ] MORAI SIM 실행 중, 지도 로드 완료 (`scripts/run_morai_launcher_nvidia.sh`로 기동)
- [ ] Scenario Runner 실행 중 (SIM flow 경유), gRPC 포트 **7789** 대기
- [ ] NVIDIA offload 환경 (SIM/Runner 측. API 클라이언트는 gRPC라 대체로 무관)
- [ ] Scenario Runner Python API 패키지 확보 완료
- [ ] `scripts/sprint0_api_contract/01_connect_no_qt.py`, `02_connect_qcore.py` 상단
      `API_SRC_DIR / API_MODULE / CLIENT_CLASS` (02는 `QT_BINDING`까지) 확정
- [ ] 민감정보 점검: 로그에 계정/토큰 노출 없는지
      `grep -i -E "token|license|auth|password|key|secret" <logfile>`

## 2. 실험 순서

1. `bash scripts/sprint0_api_contract/run_sprint0.sh` **를 사용자가 직접 실행**
   (SIM+Runner가 켜진 상태에서).
2. 러너가 **Experiment 1**(QApplication 없이)을 먼저 실행.
   - 성공(rc=0) → Qt 이벤트 루프 불필요. Experiment 2 생략.
   - 실패(rc≠0) → 러너가 **Experiment 2**(QCoreApplication 이벤트 루프)를 이어서 실행.
3. 각 실험은 `is_connected()` → `get_simulator_version()` → `get_available_map()`를
   호출하고 `RESULT`/`EXCEPTION` 라인을 남긴다.
4. 전체 출력은 `~/avstack/logs/sprint0_<timestamp>.log`로 tee 저장.
5. 로그의 RESULT/EXCEPTION을 `api_contract.md`로 옮겨 채운다.

## 3. PASS / FAIL 판정표 (integrated_roadmap.md 4장 기준)

| # | 판정 항목 | PASS 조건 | FAIL/보류 시 |
|---|---|---|---|
| P1 | API 연결 | `is_connected()`가 True 반환 | gRPC 포트/실행 순서 재점검, Runner 버전 확인 |
| P2 | 버전 조회 | `get_simulator_version()`가 버전 문자열 반환 | 예외/None이면 EXCEPTION 라인 기록 후 이슈 등록 |
| P3 | Map 목록 | `get_available_map()`가 Map 목록 반환 | 빈/예외면 기록 후 이슈 등록 |
| P4 | Qt 의존성 확정 | Exp1 성공=Qt 불필요 / Exp1 실패·Exp2 성공=Qt(루프) 필요 | 둘 다 실패면 import·바인딩·연결 재점검 |
| P5 | 산출물 | `api_contract.md` 작성 + 커밋 | — |

**Stage 03.5 PASS 기준** = P1·P2·P3 성공 + P4 확정 + P5 완료.
P4가 "Qt 필요"로 나오면 api_contract.md에 **Adapter 프로세스 격리 설계 채택**을 기록한다.

**FAIL 시**: gRPC 포트/실행 순서 재점검, Runner 버전 확인, 이슈 등록(AVS-00X, `record_issue.sh`).

## 4. 결과 기록 위치

- 원본 로그: `~/avstack/logs/sprint0_<timestamp>.log` (evidence)
- 계약 정본: 저장소 루트 `api_contract.md` (아래 템플릿) — 함수별 실측/불일치/경계신호 기록
- Stage 기록: `scripts/record_stage.sh 03_5_api_contract PASS "<요약>" "<로그경로>" "Stage03.7"`
- 문서-실동작 불일치 함수(예: `get_storyboard_element`)는 api_contract.md "불일치 목록"에 남긴다
