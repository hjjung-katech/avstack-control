# AVS-006 증거 — sourcedefender 3.7 런타임 확보 불가 (Stage 03.5 블로커)

날짜: 2026-07-03
맥락: OpenSCENARIO API 22.R3 (`~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3`)의
lib은 sourcedefender로 암호화된 694개 `.pye`. 실행하려면 sourcedefender 런타임 필요.

## 환경 (구성 완료된 부분)
- Miniconda 유저 설치 → `conda create -n morai-osc -c conda-forge python=3.7.3`
- env: **Python 3.7.3 + openssl 1.1.1w** (정확히 목표대로). pip 24 설치됨.
- 미설치: sourcedefender (아래 이유로 막힘). 그 외 deps(PyQt5/numpy==1.19.1/grpcio 1.39.0 등)는 미설치.

## 블로커 재현
```
$ .../morai-osc/bin/python -m pip install sourcedefender ...
ERROR: Ignored versions requiring different python: 15.0.x (>=3.9), 16.0.x (>=3.10)
ERROR: Could not find a version that satisfies the requirement sourcedefender (from versions: none)

$ .../morai-osc/bin/python -m pip index versions sourcedefender
ERROR: No matching distribution found for sourcedefender
```

## PyPI 실태 (pypi.org/pypi/sourcedefender/json, 2026-07-03)
- **릴리스 8개뿐**: 15.0.19~22 (`requires_python >=3.9`), 16.0.61~64 (`>=3.10`).
- **전부 sdist(tar.gz)만, wheel 없음.** cp37 파일 0개.
- 즉 **3.7 지원 버전은 PyPI에서 삭제됨.** (벤더 문서는 "3.7–3.14 지원" 주장, 실제 배포와 불일치.)

## 원인
- sourcedefender `.pye`는 암호화 당시 Python 마이너 버전(3.7)에 고정 → 3.7 런타임 필수.
- 최신 sourcedefender는 3.7 런타임 지원 중단(>=3.9/3.10). 옛 3.7 버전은 PyPI에서 pruned.
- 우회 불가: lib 전체 암호화(pb2 포함), OpenSCENARIO gRPC `.proto` 미제공(공개 grpc-docs는 SIM API용).

## 보안 주의
- sourcedefender는 복호화 후 코드를 실행하는 런타임 → 미신뢰 아카이브의 옛 바이너리 사용은 공급망 위험.
  공식 경로(MORAI/벤더)만 사용.

## 대응 (택함: MORAI 문의 + 보류)
- MORAI에 22.R3 OpenSCENARIO API의 정확한 sourcedefender 버전/설치 경로 문의.
- 확보 시: `pip install "sourcedefender==<확인버전>"` → 나머지 deps → run_sprint0.sh.

## 참고 링크
- 벤더: https://sourcedefender.co.uk , 대시보드 https://dashboard.sourcedefender.co.uk
- PyPI: https://pypi.org/project/sourcedefender/
- MORAI OpenSCENARIO API 문서: https://help-morai-sim.scrollhelp.site/ko/sim-api-guide/Working-version/openscenario-api-26.R1
