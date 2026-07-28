# NW-08 MORAI Native 킥오프 (WRX90 물리 콘솔)

> 정본 순서: 전략 §7.4 — Local Console → 5090 Display/Vulkan → **MORAI Native GUI** → Remote Access 추가 → Local/Remote 비교.
> 이 단계는 **물리 콘솔(seat0 Xorg :1, 5090/HDMI)** 에서 수행한다. 랩탑 `:1`+PRIME offload를 기본값으로 쓰지 않는다(§7.4/546). NoMachine은 이 단계 통과 후 "원격 추가"로 붙인다.
> 자산 원칙·프로버넌스 정본: `runbooks/nw01_asset_migration_plan.md`.

## 0. 준비 상태 (2026-07-28 실측, wrx90)
- 디스크 여유 768G(SIM 16G 충분) · seat0 세션=Xorg(x11) active · Vulkan/5090 discrete PASS(NW-06).
- **선행 libs 미설치**: `libxcb-xinerama0` `liblapack3` `libblas3` (AVS-001 랩탑 누락분).
- **Restore 자산 이미 안착**: `~/avstack/inbox/scenario-API-python3.13.zip` (sha256 `802248cc…c3459`, 검증됨).
- 논리경로 유지(§7.5): `~/avstack-control`, `~/avstack`.

## 1. 선행 패키지 (sudo — 사용자가 물리 콘솔/로컬 터미널에서)
```bash
sudo apt-get update
sudo apt-get install -y libxcb-xinerama0 liblapack3 libblas3 libomp5 vulkan-tools mesa-utils
```
- (첫 구동에서 라이브러리 추가 누락이 나오면 그때 `ldd`/오류 메시지로 보강. AVS-001 계열 재발 대비.)

## 2. MORAI Launcher 취득·설치 (Redownload, 계정 기반)
- MORAI 포털에 **계정 로그인** → Linux용 **MORAI Launcher** 내려받아 `~/avstack/morai/launcher/`에 설치.
  - 폴백: 포털 취득이 어려우면 랩탑 `morai/launcher/MoraiLauncher_Lin_a`(1.1G, Launcher 앱만)만 rsync. **SIM 본체(_b 16G)는 복사하지 않는다** — Launcher가 받는다.
- 실행 래퍼는 [CONTROL] git의 `scripts/run_morai_launcher_nvidia.sh` 사용(경로/GPU만 wrx90에 맞게 Adapt). 임의 직접 실행 금지(운영규칙).
- **주의**: wrx90는 5090이 주 렌더러라 랩탑의 offload 변수(`__NV_PRIME_RENDER_OFFLOAD` 등)를 승계하지 않는다. 물리 콘솔에서 기본 GL=5090.

## 3. SIM 다운로드·첫 구동 (물리 콘솔 GUI)
1. Launcher 로그인(=라이선스 인증) → **MORAI SIM 26.R1.x** 다운로드.
2. Launcher에서 SIM 실행 → 맵 로드/차량 스폰 확인(4GB 랩탑의 AVS-002 대형맵 크래시는 32GB에서 비해당, 그래도 K-City류로 시작 권장).
3. **알려진 함정 선제 적용**:
   - AVS-004/005(검은 렌더·리사이즈 크래시)는 **랩탑 NoMachine+offload 고유** → 물리 5090 콘솔에선 재발 안 하는 것이 가설. 재발 시 원격이 아닌 렌더경로로 기록.
   - ROS2 연동 단계에서 **`RMW_IMPLEMENTATION` 미설정**(AVS-007 근본원인). 래퍼 SOURCE_ROS2 블록은 이미 정정본.
   - **SIM 설정창 열림=물리 일시정지**(토픽 마지막값 반복).

## 4. 검증 증거 (필수)
- 터미널 증거는 `script` 로 `~/avstack/runs/`에 동결, 판정은 PROJECT_STATUS §2.9(임시 뷰)에 기록. **stages.tsv 혼입 금지**(원장 스키마 ADR 전).
- 스크린샷/구동 로그·`nvidia-smi`(SIM이 5090 점유) 캡처.

## 5. Remote Access 추가 (§7.4 4단계 — 물리 GUI 통과 후)
- NoMachine 설치본: `nomachine_9.8.2_1_amd64.deb`
  - URL `https://download.nomachine.com/download/9.8/Linux/nomachine_9.8.2_1_amd64.deb` · MD5 `29f24af614a1cd3da4e69c407fe31b2a`
  - 설치: `sudo dpkg -i nomachine_9.8.2_1_amd64.deb` (의존성 시 `sudo apt-get -f install`)
- Mac 클라이언트에서 **"물리 데스크톱(:1 seat0) 연결"** 로 접속(가상/offload 디스플레이 아님) → Local과 렌더 결과 비교.

## 6. 이후
- MORAI Native GUI 통과 후: SR/built-in → ROS2 native(msgs `c84d648`/26.R1 재빌드) → py API(Restore zip 설치) 순으로 Requalify.
