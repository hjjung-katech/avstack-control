# MORAI 문의 — OpenSCENARIO API 22.R3 sourcedefender 실행

## 1. 요약 (3줄 이내)
OpenSCENARIO API 22.R3의 lib이 sourcedefender로 암호화(694개 `.pye`, 암호화 시점 Python 3.7 마이너에 고정)돼 있는데,
3.7 호환 sourcedefender 런타임이 PyPI에 없어(현재 9개 릴리스 전부 `>=3.9/3.10`) API import 자체가 불가합니다.
Python 3.7.3 환경은 구성 완료했으나 sourcedefender 미확보로 Stage(API 계약 검증) 착수가 차단된 상태입니다.

## 2. 환경
- OpenSCENARIO API: **22.R3** (`~/avstack/morai/scenario_runner/OpenSCENARIO_API_22.R3`), lib = **694개 `.pye`**(sourcedefender 암호화)
- MORAI SIM: Drive **26.R1.H3**. 당사가 보유한 최신 API 배포본은 **22.R3** (최신 여부는 §5-1에서 확인 요청)
- Host: Ubuntu 22.04.5
- Python env: Miniconda(conda-forge) **python 3.7.3 + openssl 1.1.1w**, pip 24 — 구성 완료
- 기타 의존성(미설치): PyQt5, numpy==1.19.1, grpcio 1.39.0 등

## 3. 재현 절차
1. conda-forge로 `python=3.7.3` 환경 생성(openssl 1.1.1w 확인).
2. `pip install sourcedefender` → 아래 오류(§4).
3. `pip index versions sourcedefender` → `No matching distribution found`.
- 재현성: **결정론적으로 재현됨** — 의존성 해소 실패는 확률적 요소가 없으며, PyPI 릴리스 목록(§4 증거)으로
  직접 검증 가능. → **3회 재현 (2026-07-06)**.

## 4. 실측 증거
```
$ .../morai-osc/bin/python -m pip install sourcedefender          # (2026-07-06)
ERROR: Ignored the following versions that require a different python version:
  15.0.19~22 Requires-Python !=2.*,>=3.9 ; 16.0.61~65 Requires-Python >=3.10
ERROR: Could not find a version that satisfies the requirement sourcedefender (from versions: none)
ERROR: No matching distribution found for sourcedefender
```
- PyPI 실태(pypi.org/pypi/sourcedefender/json, **2026-07-06**): 릴리스 **9개** — 15.0.19~22(`!=2.*,>=3.9`), 16.0.61~**65**(`>=3.10`),
  전부 3.9/3.10 이상 요구, **3.7 호환(cp37) 0개** → 3.7 지원 버전이 PyPI에 없음. (sourcedefender 개발사 문서(공식 사이트)는 "3.7–3.14 지원" 주장, 실제 배포와 불일치.)
## 5. 질문
1. **(최우선)** 26.R1.H3와 페어링되는 최신 OpenSCENARIO API 버전이 22.R3가 맞습니까?
   sourcedefender 제약이 없거나 최신 Python을 지원하는 더 최신 API 배포가 있다면 그쪽 안내를 우선 부탁드립니다.
   (이 답에 따라 아래 질문이 전부 무효화될 수 있습니다.)
2. 22.R3 OpenSCENARIO API를 실행하는 데 필요한 **정확한 sourcedefender 버전**은 무엇입니까?
3. 그 버전은 **어디서 받습니까**? (PyPI에서 3.7 지원 버전이 삭제됨 — 벤더 계정/직접 배포 여부)
4. 지원되는 **정확한 Python 버전**은 3.7.3이 맞습니까, 아니면 다른 3.7.x 마이너입니까?
5. sourcedefender/API 사용에 **라이선스·토큰·만료 조건**이 있습니까? (dashboard.sourcedefender.co.uk 기준)
6. 22.R3 API의 **공식 설치 절차 / `requirements.txt` / 권장 환경**(conda 등)이 있습니까?

## 6. 요청 사항 / 기능 제안 (선택)
- 이 블로커의 직접 해제 수단으로 다음 중 하나를 요청합니다:
  ① Python 3.7 호환 sourcedefender 런타임(휠) **공식 제공**, 또는
  ② 현행 Python(3.10+)으로 **재암호화된 API 빌드** 제공.
