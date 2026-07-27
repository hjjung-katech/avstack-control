# AVStack 신규 Workstation Bootstrap Roadmap
## New Workstation Bootstrap Roadmap

| 항목 | 내용 |
|---|---|
| 문서 상태 | Draft 0.1 |
| 작성일 | 2026-07-27 |
| 문서 유형 | 실행 Roadmap / Gate Plan |
| 상위 기준 | `reference_workstation_environment_strategy.md` Accepted 0.9 |
| 적용 대상 | 신규 WRX90·RTX 5090 기반 Workstation |
| 관리 위치(안) | `[CONTROL]:runbooks/new_workstation_bootstrap_roadmap.md` |
| 현재 적용 여부 | 미적용 — 사용자 검토·승인 후 작업 기준으로 사용 |
| 목적 | Windows-only 출발점에서 Qualified Reference Environment, Docker·Autoware 확장 및 Second SSD Rebuild까지의 순서·Gate·산출물을 정의 |
| 비목적 | 실제 설치 명령, 정확한 Partition 수치, 특정 Driver Version, 외부 Autoware 상세 Contract |

---

# 1. Roadmap의 역할

본 문서는 승인된 `reference_workstation_environment_strategy.md`를 실제 실행 가능한 단계로 분해한다.

다음 질문에 답한다.

- 무엇을 어떤 순서로 수행하는가?
- 어느 단계에서 Human Review가 필요한가?
- 어떤 단계가 다음 단계의 선행조건인가?
- 어떤 결과와 Evidence가 있어야 Gate를 통과하는가?
- 기존 AVStack Stage와 신규 Workstation 구축단계는 어떻게 연결되는가?
- Native Reference 승인 이후 Docker와 Autoware를 어떤 순서로 확장하는가?
- Second SSD Clean Rebuild를 언제 수행하는가?

본 문서는 실제 명령을 제공하지 않는다. 각 단계의 상세 명령, 입력값, 복구 절차 및 판정 Script는 하위 Runbook에서 정의한다.

---

# 2. 핵심 운영규칙

## 2.1 신규 Workstation 결과의 독립성

기존 Laptop에서 획득한 Stage PASS는 신규 Workstation에 승계하지 않는다.

기존 결과는 Test 항목, Known Failure Mode, Script 후보, 예상 Evidence 및 신규 Host Regression 조건으로 재사용한다.

## 2.2 Build Gate와 Technical Qualification의 구분

- **Build Gate**: OS, Network, GPU, Storage, Repository 및 Runtime 배치를 준비한다.
- **Technical Qualification Gate**: MORAI, Scenario Runner, ROS 2, Python API, Batch, Reproducibility 및 Autoware Integration을 실제 기능으로 검증한다.

Build Gate 통과만으로 Reference Environment를 승인하지 않는다.

## 2.3 파괴적 변경 전 Human Approval

다음 작업은 명시적인 Human Approval 없이 실행하지 않는다.

- Windows Partition 축소·변경
- EFI·Bootloader 변경
- Secure Boot 변경
- BIOS·BMC·Firmware Update
- NVIDIA Driver 기준 변경
- Disk Formatting
- 기존 Runtime Asset 삭제
- License·Credential 이동
- Reference Environment 승인
- 외부 Release

## 2.4 Evidence 우선

각 Gate는 대상 Host·Environment, 수행일, Version, Configuration, 원본 Log, PASS/FAIL, Known Limitation, Next Action 및 Rollback 결과를 남긴다.

## 2.5 원본과 생성물의 분리

- `[CONTROL]`: 정의, Script, Runbook, Manifest, Decision, 판정
- `[WS]`: Vendor Runtime, Map, rosbag, Log, Build Output, Cache, 실행결과
- `[MGMT]`: 관련 WP·T·Milestone과 과제 관점 상태
- `[SCEN]`, `[EVAL]`: 기존 경계에 따라 실제 착수 시 사용

## 2.6 Scope Freeze

본 Roadmap이 Accepted 상태가 되기 전에는 신규 Repository 체계, Argos EOS, GitHub 업무관리 전환 등 범위 밖 설계를 병행하지 않는다.

환경 구축 중 발견한 확장 아이디어는 별도 후보로 기록하고 현재 Critical Path를 변경하지 않는다.

---

# 3. 단계 분류

## 3.1 Core Foundation

Windows 보존, Ubuntu 설치, Network, NVIDIA 및 Workspace를 준비한다.

```text
NW-00 ~ NW-07
```

## 3.2 Native Reference Qualification

MORAI·Scenario Runner·ROS 2·Python API·Batch·Reproducibility를 신규 Host에서 다시 검증한다.

```text
NW-08 ~ NW-14
```

## 3.3 Container and Autoware Expansion

Native 기준선 이후 Docker Host, Local Autoware, External Autoware 및 Simulator Distribution으로 확장한다.

```text
NW-15 ~ NW-18
```

## 3.4 Reproducibility Audit

향후 추가 SSD에서 Clean Rebuild를 수행한다.

```text
NW-19
```

---

# 4. 전체 Gate 요약

| Gate | 명칭 | 핵심 목적 | 주요 산출물 | 선행조건 | Human Gate |
|---|---|---|---|---|---|
| NW-00 | Strategy Baseline | 승인된 전략과 작업 범위 고정 | Accepted Strategy, Roadmap Draft | 없음 | 전략 승인 |
| NW-01 | Existing Asset Inventory | 기존 자산·Evidence·License 분류 | Asset Manifest, Migration List | NW-00 | Secret/License 확인 |
| NW-02 | Windows Baseline & Recovery | 출고·복구 기준점 확보 | Hardware/Disk Inventory, Recovery Evidence | NW-01 | Backup 적합성 승인 |
| NW-03 | Dual-boot Change Approval | Partition·EFI 변경안 승인 | Disk Change Plan, Rollback Plan | NW-02 | **필수 승인** |
| NW-04 | Ubuntu Base Installation | Ubuntu Host 설치 | Installed Ubuntu, Install Evidence | NW-03 | 설치 후 Acceptance |
| NW-05 | Network & Bootstrap Access | Online/Offline Package 경로 확보 | Network Qualification, Offline Kit | NW-04 | 보안 설정 검토 |
| NW-06 | NVIDIA / Display / Vulkan | RTX 5090 Host Graphics 기준선 | Host GPU Qualification | NW-05 | Driver 변경 승인 |
| NW-07 | AVStack Workspace Bootstrap | `[CONTROL]`·`[WS]` 논리경로 및 기본도구 준비 | Repository Clone, Runtime Layout, Host Manifest Draft | NW-06 | 없음 |
| NW-08 | MORAI Native Baseline | Launcher/SIM/Map 기준선 | Stage 01 신규 Host 결과 | NW-07 | Vendor License 처리 |
| NW-09 | Scenario Runner & Built-in | Runner와 Built-in Scenario 검증 | Stage 02/03 신규 Host 결과 | NW-08 | 없음 |
| NW-10 | ROS 2 Native Integration | ROS 2 Host·MORAI State·Control 검증 | Stage 04/05 신규 Host 결과 | NW-09 | 없음 |
| NW-11 | Python API & Boundary | Python 3.13 API와 Scenario 경계 검증 | Stage 03.5/03.7 결과 | NW-09 | 없음 |
| NW-12 | Batch / Reproducibility / Multi-map | Batch와 반복·Map 운용 검증 | Stage 05.5/05.7 결과 | NW-10, NW-11 | Threshold 승인 |
| NW-13 | Simulator Self-Test Baseline | 공통 Acceptance Suite 고정 | Self-Test v0, Native Baseline | NW-12 | Test 기준 승인 |
| NW-14 | Native Reference Acceptance | 신규 Host Native 기준환경 승인 | Environment Manifest, Qualification Report | NW-13 | **필수 승인** |
| NW-15 | Docker Host & Local Autoware | Container Host와 자체 Test Client 구축 | Docker GPU Test, Local Autoware Smoke Test | NW-14 | Base Image/License 검토 |
| NW-16 | External Autoware Integration | 외부 Autoware Docker와 Closed-loop 검증 | Interface Contract, Integration Result | NW-15 | Contract 승인 |
| NW-17 | Hybrid Simulator Distribution | Host MORAI + Container Service 배포형 검증 | Compose Bundle, Host Contract, Release Candidate | NW-14, NW-15 | Release Candidate 승인 |
| NW-18 | Replay/Evaluation & Full Container Decision | Replay Package 완성, Full Container 착수여부 결정 | Replay/Eval Package, Feasibility ADR | NW-13, NW-17 | Full Container 결정 |
| NW-19 | Second SSD Clean Rebuild | 문서·Script 기반 재현성 감사 | Rebuild Report, Difference Report, Final Qualification | NW-14 이상 | **필수 승인** |

---

# 5. 기존 AVStack Stage와의 Mapping

신규 `NW-*` ID는 Workstation 구축 Lifecycle을 나타낸다. 기존 Stage는 기술 Capability 검증을 나타낸다. 두 ID 체계를 합치거나 대체하지 않는다.

| 신규 Gate | 기존 Stage·자산 | 적용 방식 |
|---|---|---|
| NW-06 | Stage 00 Remote GPU | PRIME 전제를 제거하고 RTX 5090 Local Console 기준으로 재정의 |
| NW-08 | Stage 01 MORAI SIM | Launcher/SIM/Map Load를 신규 Host에서 재Qualification |
| NW-09 | Stage 02·03 | Scenario Runner와 Built-in XOSC 재Qualification |
| NW-10 | Stage 04·05 | ROS 2 Humble Host 및 MORAI ROS 2 Native 재Qualification |
| NW-11 | Stage 03.5·03.7 | Python 3.13 API와 Boundary Detection |
| NW-12 | Stage 05.5·05.7 | Batch, Calibration, Multi-map |
| NW-13 | 신규 Cross-profile Test | Native·Hybrid·Container에 공통 적용 |
| NW-15~18 | 기존 Stage 06~08 및 신규 배포형태 | 전략 승인 후 세부 Mapping 확정 |

기존 Stage의 Historical Record는 수정·삭제하지 않는다. 신규 Host의 PASS를 어떻게 기록할지는 첫 공식 Qualification 전 별도 ADR로 확정한다.

---

# 6. Critical Path

## 6.1 Native Reference Critical Path

```text
NW-00
→ NW-01
→ NW-02
→ NW-03
→ NW-04
→ NW-05
→ NW-06
→ NW-07
→ NW-08
→ NW-09
├─ NW-10 ROS 2 Native
└─ NW-11 Python API & Boundary
      ↓ (두 Gate 모두 완료)
   NW-12
→ NW-13
→ NW-14
```

NW-14 이전에는 Local/External Autoware와 Simulator Distribution을 공식 Qualification 대상으로 진행하지 않는다.

## 6.2 Expansion Path

```text
NW-14
├─ NW-15 → NW-16
└─ NW-17 → NW-18
```

Local Autoware와 Hybrid Distribution은 일부 병렬화할 수 있으나, 공통 Docker Host Foundation과 Simulator Self-Test 기준을 공유해야 한다.

## 6.3 Rebuild Path

```text
NW-14 또는 그 이후의 승인된 Environment
→ NW-19
```

Second SSD 도입 시점에 실제 Rebuild 범위를 결정한다.

---

# 7. 병렬 수행 가능한 작업

## 7.1 NW-01과 NW-02 병행 준비

- Vendor Asset 목록 작성
- Windows Hardware Inventory
- License·Account 재인증 경로 확인
- USB Offline Package 준비

단, Partition 변경은 두 Gate가 모두 통과한 뒤 수행한다.

## 7.2 NW-04~07 동안 문서화 병행

- Host Manifest Template
- Evidence Directory
- Package Inventory Script
- Network·GPU Qualification Script
- 기존 Script의 Host 종속성 분석

## 7.3 NW-08~12 동안 확장 준비

- Vendor License 확인
- Host Compatibility 항목 수집
- External Autoware 요구사항 요청
- Self-Test 구조 설계

단, Full Container 구현이나 외부 Autoware 통합은 NW-14 이전에 Critical Path를 방해하지 않는다.

## 7.4 NW-10과 NW-11의 병렬 수행

Scenario Runner와 Built-in Scenario가 확인된 NW-09 이후에는 다음 두 Gate를 병렬로 진행할 수 있다.

- NW-10: ROS 2 Native Integration
- NW-11: Python API and Boundary Detection

두 Gate는 서로의 완료를 선행조건으로 요구하지 않는다. 다만 NW-12 Batch·Reproducibility 단계에 진입하기 전에는 모두 PASS해야 한다.

---

# 8. Gate별 상세 정의

## NW-00 — Strategy Baseline

### 목적

신규 Workstation 구축의 목적·범위·원칙을 고정한다.

### 입력

- 승인된 `reference_workstation_environment_strategy.md`
- 기존 `avstack-control`
- 기존 `[WS]`와 `[MGMT]` 현황

### Exit Criteria

- 전략의 Hardware·Native·Docker·Autoware·Second SSD 방향 승인
- Roadmap 작성 기준 확정
- 추가 질문이 필요한 차단사항 없음

### Evidence

- 승인된 Strategy 문서
- 사용자 승인 기록

---

## NW-01 — Existing Asset Inventory

### 목적

기존 환경에서 무엇을 가져오고 무엇을 새로 만들지 결정한다.

### Inventory 대상

- MORAI Launcher/SIM
- Scenario Runner
- Python 3.13 API Package
- Requirements와 Checksum
- MORAI ROS 2 Message Source
- Map·Scenario
- Script·Runbook
- Conda Environment
- Vendor Communication
- License·Account 정보
- Existing Evidence
- 폐기 예정 Python 3.7 자산

### 분류

```text
Reuse as-is
Adapt and reuse
Requalify
Redownload
Restore
Regenerate
Preserve as evidence
Retire candidate
Secret/License
```

### Exit Criteria

- 필수 자산 누락 없음
- 원본·설치본·생성물 구분
- Checksum 대상 확정
- Secret·License 별도 처리
- USB 또는 Network 이관계획 준비

---

## NW-02 — Windows Baseline and Recovery

### 목적

Ubuntu 설치 전 현재 Windows·Disk·Firmware 상태를 복구 가능한 기준점으로 보존한다.

### 확인 대상

- Windows Edition/Build·Activation
- Disk·GPT·EFI·Recovery
- BitLocker·Secure Boot·Fast Startup
- BIOS/BMC Version
- GPU·Network·Storage Device
- Windows Recovery Media
- System Image 또는 대체 Recovery 방법

### Exit Criteria

- Disk Layout Evidence 확보
- Recovery 방법 검증
- 중요 Windows Data Backup
- Ubuntu 설치 전 위험요소 식별
- NW-03 Review에 필요한 정보 준비

### Human Review

Recovery가 실제로 사용 가능한지 사람이 확인한다.

---

## NW-03 — Dual-boot Change Approval

### 목적

Partition·EFI·Boot 변경을 실행하기 전에 계획과 복구방법을 승인한다.

### 필수 산출물

- 변경 전·후 Disk Layout
- Windows 축소 대상
- Ubuntu 영역
- EFI 처리방식
- Swap 전략
- Data 경로 원칙
- 실패 시 Windows Boot 복구절차
- 변경 명령 또는 Installer 선택안

### Exit Criteria

- 정확한 Partition 수치 확정
- Backup 완료
- BitLocker·Fast Startup·Secure Boot 대응 확정
- Human Approval 기록

### 금지

승인 전 Partition Tool 또는 Ubuntu Installer로 Disk를 변경하지 않는다.

---

## NW-04 — Ubuntu Base Installation

### 목적

Dual Boot가 가능한 Ubuntu Host를 설치하고 기본 부팅을 검증한다.

### 핵심 확인

- Windows 부팅
- Ubuntu 부팅
- EFI Entry
- User/Home
- Time Zone
- Basic Storage
- 기본 Console
- Reboot 안정성

### Exit Criteria

- 두 OS 부팅 가능
- Windows Recovery 손상 없음
- Ubuntu 기본 Package 관리 가능
- Install Log와 Partition 결과 보존
- 후속 Network 설정 가능

---

## NW-05 — Network and Bootstrap Access

### 목적

Ubuntu Package 설치, Git, Vendor 인증 및 Remote 관리에 필요한 Network를 확보한다.

### 우선순위

1. 실제 PCI ID 확인
2. Kernel Driver 확인
3. Wi-Fi 동작
4. 필요 시 Offline Package 경로
5. 유선 Network 사용 가능 시 주 경로 전환
6. SSH
7. Remote GUI는 Local 기준선 이후

### Exit Criteria

- Network Device와 Driver 기록
- Internet 또는 승인된 Package Source 접근
- DNS·Time 동기화
- Git/SSH 연결 가능
- Offline Bootstrap Kit 검증
- Firewall 기본방향 기록

---

## NW-06 — NVIDIA / Display / Vulkan Qualification

### 목적

RTX 5090을 신규 Host의 실제 Display·Vulkan 장치로 검증한다.

### 확인 대상

- PCI Device·Driver·Kernel Module
- `nvidia-smi`
- OpenGL Renderer
- Vulkan Physical Device
- Display Session
- Local Console
- GPU Memory
- Reboot 후 동일성

### 기존 환경과의 차이

- PRIME Offload를 기본 적용하지 않는다.
- `DISPLAY=:1`을 고정하지 않는다.
- Local Console을 최초 기준선으로 사용한다.

### Exit Criteria

- NVIDIA GPU와 Vulkan 정상
- Software Renderer가 아님
- Display Session 정보 기록
- Driver Rollback 경로 준비
- MORAI Native 설치 착수 가능

### Human Review

Driver 설치·변경 전에 Package와 Rollback을 확인한다.

---

## NW-07 — AVStack Workspace Bootstrap

### 목적

기존 운영 경계를 유지하면서 신규 Host의 `[CONTROL]`과 `[WS]`를 준비한다.

### 기본 논리경로

```text
~/avstack-control
~/avstack
```

### 주요 작업

- `[CONTROL]` Clone
- 신규 Host Manifest Draft
- `[WS]` Directory
- Evidence·Run Directory
- Git Identity
- Secret 제외
- 기존 Script의 PRIME·DISPLAY·Home 경로 검토
- Host별 Qualification 기록방식 ADR 준비

### Exit Criteria

- Repository 검증
- Runtime Directory 준비
- Secret과 Vendor Asset 미포함
- Host 종속 Script 목록 작성
- 기존 Stage Record와 신규 Host Record의 분리방식 제안

---

## NW-08 — MORAI Native Baseline

### 목적

신규 GPU·Display·Ubuntu 환경에서 MORAI Launcher와 SIM을 Native로 검증한다.

### 확인 대상

- Vendor Asset 복원
- Account/License
- Launcher·SIM
- 기준 Map·대형 Map
- GPU/Vulkan
- 정상 종료
- Window Resize
- Local/Remote 차이

### Exit Criteria

- 기준 Map 정상
- GPU Memory와 Performance 기록
- 대형 Map 결과 기록
- Critical Crash 없음
- Known Limitation 정리
- Stage 01에 해당하는 신규 Host Evidence 확보

---

## NW-09 — Scenario Runner and Built-in Scenario

### 목적

Scenario Runner GUI와 Built-in Scenario 실행을 확인한다.

### 확인 대상

- Native Dependency
- GUI Rendering
- Launcher 연동
- gRPC 7789
- `.xosc`
- Map 정합
- Ego Built-in
- Start/Stop
- Log/Result
- 기존 Black-screen 이슈 재현 여부

### Exit Criteria

- Runner UI 사용 가능 또는 명확한 Workaround
- 기준 Scenario 실행·Ego 동작·종료
- Stage 02/03 신규 Host Evidence 확보

---

## NW-10 — ROS 2 Native Integration

### 목적

ROS 2 Humble Host와 MORAI ROS 2 Native 양방향 통신을 신규 Host에서 확인한다.

### 기존 Regression 조건

- MORAI Message Workspace 소싱
- Simulator Process에서 `RMW_IMPLEMENTATION` 미설정
- `ROS_LOCALHOST_ONLY=0`
- ROS2 Connect
- 설정창 닫힘
- `/ego_vehicle_status`
- 실제 Frequency
- `CtrlCmd`
- Vehicle Response와 Stop

### Exit Criteria

- ROS 2 Host 기본 Test
- MORAI Topic Discovery
- 상태 Data 수신
- Control Command 반영
- 물리 동작과 Topic 상태 구분
- Stage 04/05 신규 Host Evidence 확보

---

## NW-11 — Python API and Boundary Detection

### 목적

Python 3.13 재빌드 API의 재현성과 실제 Scenario Lifecycle을 확정한다.

### 확인 대상

- Conda Environment 재생성
- 절대 `prefix` 제거
- `sourcedefender 16.0.65`
- API Import
- Client/Importer
- Scenario Import
- Start/Stop
- `get_stop_status`
- Callback
- Qt Event Loop 요구
- Log/Result Boundary

### Exit Criteria

- Stage 03.5 PASS
- Stage 03.7 PASS
- API Contract 갱신
- Boundary Detection 기준 확정
- Python 3.7 환경 폐기 판단 가능

---

## NW-12 — Batch, Reproducibility and Multi-map

### 목적

Native Reference가 단일 Scenario Demo가 아니라 반복 가능한 평가환경인지 검증한다.

### 확인 대상

- Batch Runner
- Run별 Artifact
- Atomic Output
- Scenario Boundary
- Repeated Execution
- Threshold Calibration
- Map 전환·Cleanup
- Failure/Invalid Run 판정
- Result Schema

### Exit Criteria

- Stage 05.5 PASS
- Stage 05.7 PASS
- 기준 반복 Test 완료
- Map 운용전략 확정
- Autoware 착수 Gate 충족

---

## NW-13 — Simulator Self-Test Baseline

### 목적

Native와 향후 Container 환경에 공통 적용할 Acceptance Suite를 고정한다.

### Test 영역

- Startup·Health
- Map/Ego
- Scenario Lifecycle
- gRPC/API
- ROS 2 Topic/Type/QoS
- Clock
- Vehicle State·Control
- Log/Result
- Cleanup·Repeatability

### Exit Criteria

- Test Case와 Input 고정
- 자동·수동 판정 구분
- Evidence Format 확정
- Native Baseline 결과 확보
- Container 비교가 가능한 상태

### Human Review

Acceptance Criteria와 허용오차를 사람이 승인한다.

---

## NW-14 — Native Reference Acceptance

### 목적

신규 Workstation의 Native 환경을 공식 Reference Candidate로 승인한다.

### 필수 입력

- Host/Environment Manifest
- NW-06~13 결과
- Version Inventory
- Known Limitation
- Recovery·Rollback 정보
- Self-Test 결과

### 판정

```text
Accepted
Conditionally Accepted
Rejected
```

### Exit Criteria

- 환경 ID와 Version 부여
- 승인일·판정자 기록
- 제한사항 공개
- Docker·Autoware 확장 기준선 확보

### Human Review

필수다.

---

## NW-15 — Docker Host Foundation and Local Autoware

### 목적

Native Reference를 훼손하지 않고 Container Host와 자체 Test용 Autoware를 구축한다.

### 주요 작업

- Docker Engine
- NVIDIA Container Runtime
- GPU Container Test
- Base Image Pinning
- Volume·Network 기준
- Local Autoware Runtime/Dev Image
- 최소 Map·Vehicle·Sensor
- Smoke/Closed-loop Test

### Exit Criteria

- GPU Container 정상
- Local Autoware 기동
- Simulator Interface Test
- Native 환경 영향 없음
- Image Digest와 Configuration 기록

---

## NW-16 — External Autoware Integration

### 목적

외부 담당자가 제공한 Autoware Docker를 동일 Interface 기준으로 검증한다.

### 필요한 Contract

- Image Digest
- ROS 2/RMW·Domain
- Topic/Type/QoS
- TF·Clock
- Map·Vehicle State·Control
- Lifecycle·Health
- Log/Error

### Exit Criteria

- Local과 External 환경의 차이 분석
- Closed-loop Test
- Contract 위반 또는 Adapter 필요사항 식별
- 외부 Image Version별 결과 기록

### Human Review

Breaking Change와 Contract 승인에 필요하다.

---

## NW-17 — Hybrid Simulator Distribution

### 목적

MORAI는 Host Native에 유지하고 이식 가능한 Service를 Container로 배포한다.

### 후보 구성

- Orchestrator
- Adapter
- Health Check
- Self-Test
- Evaluation
- Local Autoware Test

### Exit Criteria

- Compose Bundle
- Host Compatibility Contract
- Asset 준비 절차
- Self-Test PASS
- Native Baseline과 비교
- Upgrade/Rollback
- Release Candidate

---

## NW-18 — Replay/Evaluation and Full Container Decision

### 목적

가장 이식성 높은 Replay/Evaluation Package를 확보하고 MORAI Full Container 착수여부를 결정한다.

### Replay/Evaluation Exit Criteria

- rosbag·eventlog·statelog 입력
- KPI·Verdict 재계산
- Result 비교
- Container 또는 독립 실행
- CI 후보
- Version과 Fixture

### Full Container Decision 기준

- License·Vendor Support
- GPU/Vulkan·GUI
- DDS/gRPC·Data
- Performance·Native 동등성
- 실제 배포가치

조건이 부족하면 `Deferred`로 남긴다.

---

## NW-19 — Second SSD Clean Rebuild

### 목적

Reference Environment가 문서와 자동화만으로 재구축 가능한지 검증한다.

### 기본 원칙

- Clone을 공식 방식으로 사용하지 않음
- 새 SSD Clean Install
- 동일 Logical Path
- Asset Checksum
- 동일 Self-Test
- Difference Report
- Hidden Dependency 식별

### Exit Criteria

- Host Foundation 재구축
- Native Reference 재Qualification
- 필요시 Container/Autoware 재구축
- 기존 환경과 차이 설명
- Reproducibility 판정
- 기존 SSD의 향후 역할 결정

### Human Review

새 SSD 전환과 기존 환경 정리는 사람이 승인한다.

---

# 9. Evidence와 Record 원칙

## 9.1 기본 Evidence 위치

정확한 Directory는 하위 Runbook에서 확정하되 다음 경계를 유지한다.

```text
[WS]
~/avstack/runs/
~/avstack/logs/
~/avstack/results/

[CONTROL]
records/
manifests/
runbooks/
필요한 동결 Evidence
```

## 9.2 신규 Host 식별

최초 Host Manifest 생성 전까지 기존 `stages.tsv`에 신규 PASS를 혼입하지 않는다.

Host별 Qualification Schema는 NW-07에서 ADR 후보를 작성하고 NW-08의 첫 공식 판정 전에 확정한다.

## 9.3 완료 기록

각 Gate 완료 시 Gate 상태, Summary, Evidence, Known Limitation, Next, 관련 Issue/Decision, Session Report 및 필요한 `[MGMT]` 포인터를 반영한다.

---

# 10. Rollback 원칙

각 하위 Runbook은 다음을 포함해야 한다.

- 변경 전 State
- 변경 대상과 예상 영향
- Backup
- 취소조건
- Rollback 절차
- Rollback 검증
- 실패 Evidence

특히 NW-03, NW-04, NW-06, NW-15, NW-19는 Rollback이 없는 상태에서 착수하지 않는다.

---

# 11. Roadmap Milestone

| Milestone | 범위 | 의미 |
|---|---|---|
| M0 Strategy Accepted | NW-00 | 전략 기준선 확정 |
| M1 Safe Dual-boot Host | NW-01~05 | Windows 보존과 Ubuntu 기반 확보 |
| M2 Qualified GPU Host | NW-06~07 | NVIDIA/Vulkan과 Workspace 준비 |
| M3 Native Simulator Functional | NW-08~11 | MORAI·Scenario·ROS 2·API 기능 확보 |
| M4 Native Evaluation Ready | NW-12~13 | Batch·Reproducibility·Self-Test 확보 |
| M5 Accepted Native Reference | NW-14 | 공식 Native 기준선 승인 |
| M6 Autoware Integration Ready | NW-15~16 | Local·External Autoware 통합 |
| M7 Distributable Hybrid Environment | NW-17~18 | Hybrid 배포와 Replay/Eval 확보 |
| M8 Reproducibility Proven | NW-19 | Second SSD 재구축 검증 |

---

# 12. 즉시 파생할 문서

Roadmap 승인 후 다음 순서로 작성한다.

1. `existing_environment_asset_migration.md`
2. `windows_baseline_and_recovery.md`
3. `install_ubuntu_dualboot.md`
4. `qualify_network_and_remote_access.md`
5. `install_and_qualify_nvidia.md`
6. `bootstrap_avstack_workspace.md`

NW-07 이후의 기술 Runbook은 해당 Gate에 진입하기 전에 작성·리뷰한다. 아직 설치하지 않을 Docker·Autoware 상세문서를 한꺼번에 작성하지 않는다.

---

# 13. Roadmap 완료 기준

본 Roadmap은 다음을 만족할 때 Accepted 상태로 전환한다.

- 승인된 Core Strategy와 일치한다.
- 기존 Stage와 신규 Workstation Gate가 구분된다.
- Windows 보존과 Dual Boot 위험이 반영된다.
- Native Reference가 Docker·Autoware보다 선행한다.
- Stage 03.7, 05.5, 05.7 Gate가 유지된다.
- Self-Test가 공통 Acceptance Suite로 정의된다.
- Human Approval 시점이 명확하다.
- Second SSD Rebuild가 최종 Reproducibility Audit으로 연결된다.
- 각 Gate가 별도 Runbook으로 분해 가능하다.
- Scope 밖 항목이 Roadmap Critical Path에 포함되지 않는다.
- 사용자 검토와 승인을 받는다.

---

# 14. Roadmap 요약

```text
기존 자산 파악
→ Windows 기준점과 Recovery
→ 안전한 Dual Boot
→ Ubuntu Network·NVIDIA Host
→ AVStack Workspace
→ MORAI·Scenario Runner
→ ROS 2 Native
→ Python API·Boundary
→ Batch·Reproducibility·Multi-map
→ Simulator Self-Test
→ Native Reference 승인
→ Docker Host·Local Autoware
→ External Autoware
→ Hybrid Distribution·Replay/Evaluation
→ Full Container 여부 결정
→ Second SSD Clean Rebuild
```

이 순서는 신규 Workstation의 실제 안정성과 재현성을 먼저 확보하고, 그 위에서 배포와 Integration을 확장하도록 설계되었다.
