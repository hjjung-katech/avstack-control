# Stage 03.5 — Python API 계약 검증 체크리스트

작업 정의: `runbooks/integrated_roadmap.md` 4장. 목적은 Scenario Runner Python API의
실제 동작 계약을 **실측으로 확정**하는 것(문서를 믿지 않고 계약을 실측).

- 선행: Stage 03 PASS (완료)
- 관련 결정: ADR-007(통합 로드맵), ADR-008(프레임워크 별도 저장소)
- 산출물: 저장소 루트 `api_contract.md`, (있으면) 프레임워크 repo `VERSIONS.lock`

---

## 0. 획득 결과 + 실물 API 파악 (2026-07-03)

**패키지 획득/배치 (완료)**
- `OpenSCENARIO_API_22.R3.zip` → 해제 → **`~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3/`** 로 이동 완료.
  (zip 원본은 `~/Downloads`에 백업 유지.) 구성: `main.py`, `open_scenario_client_wrapper.py`,
  `open_scenario_importer_wrapper.py`, `lib/`(암호화), `data/openscenario/`(K-City·Suburb·EuroNCAP 등).

**버전 정리 (사용자 확인)**
- **26.R1 = MORAI SIM(Drive) 버전.** OpenSCENARIO **API의 최신은 22.R3** (링크: SIM API Guide →
  `.../ko/sim-api-guide/Working-version/openscenario-api-26.R1` 페이지에 버전별 zip 링크).
- 22.R3 API가 26.R1 SIM에 붙는 조합으로 진행.

**실물 API 표면 (예제 소스 확인)** — 문서의 `OpenScenarioClientAPI`가 아니다:
- `OpenScenarioClientWrapper(ip, port)` / `OpenScenarioImporterWrapper()` (패키지 루트 모듈)
- 하위 `from lib.openscenario.client.open_scenario_client import OpenScenarioClient`
- 흐름: import_open_scenario → set_open_scenario_importer → start_scenario → `get_stop_status()` 폴링
- `is_connected/get_simulator_version/get_available_map`는 **없음**(api_contract.md 4장 불일치표).

**⚠️ 실행 요구 (중요)**
- **Python 3.7.3 전용** — lib이 `sourcedefender`로 암호화되어 파이썬 버전에 잠김. OS는 호환.
  현재 시스템 python은 **3.10뿐**(3.7 없음, pyenv/conda 없음) → **3.7.3 venv/인터프리터 선행 구성 필요**.
- 의존성: `sourcedefender`, `PyQt5`, `numpy==1.19.1`, `grpcio`/`grpcio-tools`, scipy, matplotlib, eventhandler, pyproj.
- (파이썬 설치·pip 설치는 CLAUDE.md 규칙상 **사용자 확인 후**.)

---

## 0.1 현재 블로커 — AVS-006 (2026-07-03, Stage 03.5 보류)

Python 3.7.3 env(miniconda `morai-osc`, openssl 1.1.1w)까지 구성 완료. 그러나 lib이 **sourcedefender
암호화(.pye 694개)** 이고 **3.7용 sourcedefender 런타임을 PyPI에서 구할 수 없다**(릴리스 8개 전부 >=3.9/3.10,
wheel 없음). → API import 불가. 증거: `~/avstack/logs/avs006_sourcedefender_py37_block_20260703.md`.

**해제 조건**: 3.7 호환 sourcedefender 런타임 확보. **MORAI 문의**가 권위 있는 경로.

**MORAI 문의 포인트 (그대로 사용):**
1. OpenSCENARIO API **22.R3**(Linux)를 **Python 3.7.3**에서 실행하려면 **sourcedefender 어느 버전**이 필요한가?
2. 그 버전을 어디서 받는가? (PyPI에서 3.7 버전이 삭제됨 — 벤더 계정/직접 배포 여부)
3. 26.R1 SIM과 붙는 **최신 OpenSCENARIO API 버전**은 22.R3가 맞는가? 더 최신(예: 26.R1 대응)이 있으면 링크.
4. (있으면) 정식 `requirements.txt` / 설치 가이드.

확보 후: `pip install "sourcedefender==<버전>"` → 나머지 deps → §2 실험 재개.

## 1. 실행 전 조건 (preflight)

- [ ] MORAI SIM 실행 중, 지도 로드 완료 (`scripts/run_morai_launcher_nvidia.sh`)
- [ ] Scenario Runner 실행 중 (SIM flow 경유), gRPC 포트 **7789** 대기
- [ ] **Python 3.7.3 인터프리터/venv 준비** 후 `PYTHON=<3.7.3 경로>`로 지정
- [ ] 3.7.3 env에 의존성 설치: `sourcedefender PyQt5 numpy==1.19.1 grpcio grpcio-tools scipy matplotlib eventhandler pyproj`
- [ ] 패키지 경로 확인: `MORAI_OSC_API=~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3`
- [ ] 민감정보 점검: 로그에 계정/토큰 노출 없는지
      `grep -i -E "token|license|auth|password|key|secret" <logfile>`

## 2. 실험 순서

1. `PYTHON=<3.7.3> bash scripts/sprint0_api_contract/run_sprint0.sh` **를 사용자가 직접 실행**
   (SIM+Runner가 켜진 상태에서).
2. **Experiment 1**(01_connect_no_qt.py, QApplication 없이): `sourcedefender`+wrapper import →
   `OpenScenarioClientWrapper('127.0.0.1','7789')` 생성 → `get_stop_status()` 조회.
   - 성공(rc=0) → Qt 루프 불필요. Experiment 2 생략.
   - 실패(rc≠0) → **Experiment 2**(02_connect_qcore.py, PyQt5 `QApplication` 하에서) 자동 실행.
3. 전체 출력은 `~/avstack/logs/sprint0_<timestamp>.log`로 tee.
4. 로그의 RESULT/EXCEPTION을 `api_contract.md`로 옮겨 채운다.

## 3. PASS / FAIL 판정표 (실물 22.R3 기준으로 재정의)

| # | 판정 항목 | PASS 조건 | FAIL/보류 시 |
|---|---|---|---|
| P0 | 환경 | Python 3.7.3 + 의존성 import 가능 | 3.7.3 venv 재구성, 누락 dep 설치 |
| P1 | lib 로드 | `import sourcedefender` 후 wrapper import 성공 | py 버전/sourcedefender 확인 |
| P2 | 클라이언트 생성 | `OpenScenarioClientWrapper('127.0.0.1','7789')` 예외 없이 생성 | gRPC 7789/실행 순서/Runner 확인 |
| P3 | 상태 조회 | `get_stop_status()`가 bool 반환 | 예외면 기록 후 이슈 등록 |
| P4 | Qt 의존성 확정 | Exp1 성공=루프 불필요 / Exp1 실패·Exp2 성공=루프 필요 | 둘 다 실패면 PyQt5/연결 재점검 |
| P5 | 산출물 | `api_contract.md` 작성 + 커밋 | — |

**Stage 03.5 PASS 기준** = P0·P1·P2·P3 성공 + P4 확정 + P5 완료.
P4가 "루프 필요"면 api_contract.md에 **Adapter 프로세스 격리 설계 채택**을 기록한다.
(문서의 is_connected/version/map 스모크는 실물 부재로 위 항목으로 대체 — api_contract.md 4장 참조.)

**FAIL 시**: 3.7.3 환경/gRPC 포트/실행 순서/Runner 버전 재점검, 이슈 등록(AVS-00X, `record_issue.sh`).

## 4. 결과 기록 위치

- 원본 로그: `~/avstack/logs/sprint0_<timestamp>.log` (evidence)
- 계약 정본: 저장소 루트 `api_contract.md` — 함수별 실측/불일치/경계신호 기록
- Stage 기록: `scripts/record_stage.sh 03_5_api_contract PASS "<요약>" "<로그경로>" "Stage03.7"`
- 경계 감지 1차 신호 후보: `get_stop_status()` 폴링 → Stage 03.7로 인계
