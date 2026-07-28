# NW-01 자산 인벤토리 · 이관/재검증 계획 (Laptop t15p → WRX90)

> 정본 원칙: 전략 §9(기존 자산 활용과 Migration). "정의는 git, 재생성물은 밖." **랩탑 `~/avstack` 통째 복제 금지.**
> 이 문서는 판정(verdict)이 아니라 **절차/계획**이다. 게이트 판정은 PROJECT_STATUS §2.9(임시 뷰) — 원장 스키마 확정(NW-07 후속 ADR) 전까지 `stages.tsv` 혼입 금지.

## 1. 소스 접근 채널
- wrx90 전용 SSH 키 `~/.ssh/wrx90_t15p`(ed25519) → 랩탑 `authorized_keys` 등록 완료. 비대화식 접속 검증됨.
- 용도 = **인벤토리(§9.2) + Restore 소량 전송 한정**. 대량 rsync 클론 아님.
- 인벤토리 증거(동결): `~/avstack/runs/nw01_laptop_inventory_20260728_085812.txt` (wrx90, non-git [WS]).

## 2. 확정 프로버넌스 (랩탑 실측 2026-07-28)
| 항목 | 값 |
|---|---|
| MORAI_SIM | **26.R1.x** (Launcher 다운로드본, `morai/launcher/MoraiLauncher_Lin_b` 16G) |
| ScenarioRunner | 1.7.0 |
| OpenSCENARIO API | 22.R3 (`morai/scenario_runner/OpenSCENARIO_API_22.R3`) |
| py3.13 API 원본 | `inbox/scenario-API-python3.13.zip` sha256 `802248ccb8c93f3c7da4fca1a6c9fcb78965f7106c7ac5515346e677669c3459` |
| morai_msgs 리포 | `github.com/MORAI-Autonomous/MORAI-ROS2_morai_msgs.git` @ `c84d648638510d28b691b959b03502009f4e2070` (tag **26.R1**) |
| ROS / RMW | humble / VERSIONS.lock엔 `rmw_cyclonedds_cpp`이나 **AVS-007상 RMW 미설정이 정답 — 그대로 승계 금지** |
| 라이선스 | **MORAI 계정 로그인** (KEYLOK 동글 아님). wrx90에서 로그인만으로 인증·다운로드 가능(사용자 확인 2026-07-28) |
| 구 호스트 | RTX 3050 / driver 580.159.03 (wrx90 = RTX 5090 / 580-open, 재기록 대상) |

## 3. 자산 분류 (전략 §9.1)
| 랩탑 자산 | 클래스 | 처리 |
|---|---|---|
| `morai/launcher/_b` SIM 26.R1.x (16G) | **Redownload** | 계정 로그인 후 재다운. 복사 안 함 |
| `morai/launcher/_a` Launcher 앱 (1.1G) | Redownload | 벤더 Launcher 재취득 |
| 라이선스(계정) | Secret/License | wrx90에서 계정 로그인. 파일 이관 없음 |
| `inbox/scenario-API-python3.13.zip` (3.66M) | **Restore** ← 유일 필수 전송 | rsync + sha256 검증 후 wrx90에서 재설치 |
| `scenario_api_py313/` 설치본 | Regenerate | 복사 안 함(원본 zip에서 재설치) |
| `scenario_runner/OpenSCENARIO_API_22.R3` (127M) | Restore/Requalify | 재취득·재검증 (py313 경로로 대체 시 Retire 후보) |
| `ros2_ws_26r1/src/morai_ros2_msgs` | Redownload | 위 commit 고정 재클론 → colcon build. build/install/log=Regenerate |
| `ros2_ws` (구) | **Retire** | ros2_ws_26r1로 대체 |
| conda `morai-osc-py313` | Reuse(yml) | git `environment-morai-osc-py313.yml`로 재생성(prefix 제거) |
| conda `morai-osc` (py3.7대) | **Retire** | AVS-006 폐기 경로 |
| `scenarios/` (빈 디렉터리) | Reuse(git[SCEN]) | 정의는 oss3-scenarios |
| `VERSIONS.lock` | Adapt | wrx90용으로 RMW/NVIDIA/호스트 필드 재기록 |
| `inbox/*.eml`, `logs/`, `runs/` | Preserve(랩탑) | 증거. 이관 안 함 |

## 4. 실행 순서 (요약 — SIM 실제 구축은 NW-08+에서 판정)
1. **Restore 전송**: `rsync -av` 로 랩탑 `inbox/scenario-API-python3.13.zip` → wrx90 `~/avstack/inbox/`, 이후 `sha256sum` 대조(§2 값).
2. **정의 확보**: [CONTROL]/[SCEN] git에서 wrapper·conda yml·시나리오·VERSIONS.lock 템플릿 체크아웃.
3. **Redownload 신규 설치(wrx90)**: MORAI Launcher → 계정 로그인 → SIM 26.R1.x 다운로드 / OpenSCENARIO API / conda env(yml) / msgs(commit 고정 clone→colcon) / py3.13 API(Restore zip에서 설치).
4. **Requalify**: NW-06(GPU/Vulkan) 이후 NW-08~ 로 Launcher→SIM→SR→built-in→ROS2 native→py API→boundary 를 **wrx90에서 재판정**. 알려진 해법을 선제 적용: **AVS-007 RMW 미설정**, 누락 라이브러리(libxcb-xinerama0 등), AVS-006 py3.13 경로.
5. **Retire/Preserve**: 구 `ros2_ws`·`morai-osc` 미이관. logs/runs/eml는 랩탑 증거로 보존.

## 5. 열린 항목
- OpenSCENARIO_API_22.R3(SR측)이 py3.13 API 경로와 중복인지 → Stage 03.5 상당 재검증 시 Retire 여부 확정.
- wrx90 원격 GUI 접근 방식(NoMachine→`:0` vs offload)은 NW-08 착수 시 결정(전략 §7.4 Local Console 기준선 우선).
