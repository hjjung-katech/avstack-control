# Python API (V1 Scenario API, py3.13) 준비성 정적 분석 — WRX90

> NW-01 Restore 자산 `scenario-API-python3.13.zip`(sha256 `802248cc…c3459`)의 **정적 분석**(실행/설치 아님, 게이트 안전). Python API 게이트(랩탑 Stage 03.5 상당) 착수 전 준비 근거.
> 자율 작업 A(2026-07-28). 증거: `~/avstack/runs/nw_api313_static_20260728.txt`. 관련: AVS-006(py3.13 경로), `runbooks/nw01_asset_migration_plan.md`.

## 1. 패키지 정체
- **MORAI V1 Scenario API (Python 3.13)** — `.xosc`(OpenSCENARIO) 시나리오를 실행 중인 MORAI SIM에 대해 gRPC(`127.0.0.1:7789`)로 구동.
- 293 files, 6.26MB. 대부분 **`.pye`(sourcedefender 암호화)** 코어 + 평문 래퍼 3개.
- 트리: `lib/common`, `lib/mgeo`(맵 지오메트리 class_defs), `lib/openscenario`(OpenSCENARIO class_defs 전체 + `api/`). 최상위: `main.py`, `open_scenario_client_wrapper.py`, `open_scenario_importer_wrapper.py`, `requirements-release.txt`.

## 2. 공개 API 표면 (평문 래퍼 2 클래스)
- **`OpenScenarioImporterWrapper()`**
  - `import_open_scenario(xosc_path)` — .xosc 파싱 → 참조 MGeo 폴더 경로 획득 → `MGeo.create_instance_from_json(folder)`로 맵 로드 → `set_mgeo` → `update_scenario_data`.
  - `.scenario_importer` (속성, 클라이언트에 전달), `.clear()`.
- **`OpenScenarioClientWrapper(ip, port)`**
  - `set_open_scenario_importer(importer.scenario_importer)`, `start_scenario()`, `stop_scenario()`, `get_stop_status()`(bool, True=실행중), `start/stop_scenario_callback`(no-op, 재정의 가능 — runner가 등록 요구).
- **생명주기**(main.py): importer.import → client.set_importer → `start_scenario()` → `while get_stop_status(): sleep(1)` → 종료 시 자동 stop.

## 3. 의존성 (requirements-release.txt)
`sourcedefender`(=.pye 복호화), `numpy`, `grpcio`, `protobuf`, `pycryptodome`, `scipy`, `shapely`, `pyproj`, `matplotlib`. 선택(lazy): `iso3166`, `gdal`.

## 4. 게이트 착수 선행조건 (도달 시)
1. **Python 3.13 conda env** + 위 deps. ⚠️ wrx90엔 **conda 미설치**(miniconda 선행 필요, 제 Bash는 외부 다운로드 차단 → 사용자/물리).
2. **sourcedefender 버전 고정** — 복호화는 버전 민감(AVS-006: **16.0.65**). requirements는 unpinned → **핀 고정 필요.**
3. **SIM Python-API gRPC 활성** — `127.0.0.1:7789` 리슨. 랩탑 Stage 03.5의 미결 "GRPC Connect 필요"에 해당(SIM 설정/모드).
4. **시나리오 입력** — `.xosc` + 참조 MGeo(JSON)는 **패키지에 없음**(§5). SIM 내장 시나리오/맵 또는 [SCEN] oss3-scenarios에서 소싱.

## 5. 발견/리스크
- **R1 data/ 미동봉**: 코드 전용. main.py 예제(`R_KR_PG_K-City/Scenario_CCRB_*`, `V_RHT_Suburb_03/*`)는 SIM 동봉 맵 참조 — 입력을 별도 확보해야 함.
- **R2 Windows 경로 구분자**: main.py `scenario_list`가 `.\data\openscenario\...` (백슬래시). **Linux에선 백슬래시가 구분자가 아니라 리터럴** → `os.path.join`/`normpath`로 분리 안 됨. 실사용 시 forward slash로 교체(예제 자체는 참고용).
- **R3 sourcedefender 핀**: unpinned. 잘못된 버전이면 .pye import 실패(AVS-006 재현).
- **R4 지오 deps 무게**: `gdal`/`pyproj`/`shapely`는 시스템 라이브러리 의존 가능 — env 생성 시 확인.

## 6. 다음(게이트 도달 시, 요약)
miniconda 설치 → py3.13 env(deps + sourcedefender 16.0.65) → 패키지를 `~/avstack/morai/scenario_api_py313`에 배치 → import smoke(`main.py`의 두 래퍼 import) → SIM gRPC 활성 후 단일 .xosc 실행 계약 검증. **지금은 정적 분석까지만(게이트 미착수).**
