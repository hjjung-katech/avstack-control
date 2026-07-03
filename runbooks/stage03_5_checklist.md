# Stage 03.5 — Python API 계약 검증 체크리스트

작업 정의: `runbooks/integrated_roadmap.md` 4장. 목적은 Scenario Runner Python API의
실제 동작 계약을 **실측으로 확정**하는 것(문서를 믿지 않고 계약을 실측).

- 선행: Stage 03 PASS (완료)
- 관련 결정: ADR-007(통합 로드맵), ADR-008(프레임워크 별도 저장소)
- 산출물: 저장소 루트 `api_contract.md`, (있으면) 프레임워크 repo `VERSIONS.lock`

---

## 0. step1 확인 결과 (2026-07-03)

- 현재 MORAI 설치본의 Scenario Runner는 **PyInstaller 프리즈 바이너리**뿐:
  `.../ScenarioRunner/scenario_runner_v1.7.0_linux/{runner, program/Scenario Runner, program/_internal/}`.
- **API import 모듈·`.whl`·pip 패키지 없음** → 문서의 Python API는 **별도 배포물**.
- ⇒ 실험 전 **API 패키지 확보 + 01/02 스크립트 상단 TODO(import 경로) 확정**이 필요하다.

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
