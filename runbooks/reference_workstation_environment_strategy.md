# AVStack Reference Workstation 환경 구축 전략
## Reference Workstation Environment Strategy

| 항목 | 내용 |
|---|---|
| 문서 상태 | Accepted 0.9 |
| 작성일 | 2026-07-27 |
| 문서 유형 | 상위 환경전략 |
| 적용 대상 | 신규 WRX90 기반 AVStack Workstation |
| 관리 위치(안) | `[CONTROL]:runbooks/reference_workstation_environment_strategy.md` |
| 작성 목적 | 신규 Workstation의 목표 환경, 설계 철학, 전환·복구·재현·검증 및 장기 확장 방향을 정의 |
| 현재 적용 여부 | 승인됨 — Bootstrap Roadmap 및 하위 Runbook의 상위 기준으로 적용 |
| 관련 정본 | `[CONTROL]:CLAUDE.md`, `[CONTROL]:PROJECT_STATUS.md`, `[CONTROL]:runbooks/repo_boundaries.md`, `[CONTROL]:records/*.tsv`, `[MGMT]` 관련 WP·T·Milestone |
| 후속 문서 | Bootstrap Roadmap, Asset Migration, Windows Baseline, 단계별 설치·Qualification Runbook |

---


> [!note] 승인 기록
> 본 전략은 2026-07-27 Human Project Owner의 검토를 거쳐 **Accepted 0.9** 상태로 승인되었다.
> 실제 신규 Workstation 구축과 Qualification 결과를 반영한 뒤 Baseline 1.0 전환 여부를 판단한다.

# 1. 문서 목적과 역할

## 1.1 목적

본 문서는 Windows만 설치된 신규 고성능 Workstation에 Ubuntu 기반 AVStack 환경을 구축하기 위한 최상위 전략을 정의한다.

이번 작업의 결과는 단순히 Ubuntu와 개발도구가 설치된 개인 PC가 아니다. 다음 조건을 만족하는 **Reference Workstation Environment**를 구축하는 것이 목적이다.

- 실제 Simulator와 ROS 2 환경이 안정적으로 동작한다.
- 설치·설정·변경 내역을 추적할 수 있다.
- 장애 발생 시 이전 정상 상태로 복구할 수 있다.
- 동일한 환경을 새 SSD 또는 다른 호환 Host에 다시 구축할 수 있다.
- Native 실행 결과를 Docker 환경의 기준선으로 사용할 수 있다.
- 자체 Test용 Autoware와 외부 제공 Autoware Docker를 모두 검증할 수 있다.
- 향후 Simulator 환경을 내부 또는 외부에 재현 가능한 형태로 제공할 수 있다.

본 문서는 “어떻게 명령을 실행하는가”를 설명하는 설치 Runbook이 아니다. 다음을 결정하는 상위 기준 문서다.

- 왜 이 환경을 만드는가
- 어떤 환경을 완성해야 하는가
- 기존 환경의 무엇을 활용하고 무엇을 다시 검증하는가
- Native, Docker, Autoware의 관계를 어떻게 설정하는가
- Recovery와 Rebuild를 어떻게 구분하는가
- 어떤 조건에서 Reference Environment로 승인하는가
- 이후 어떤 Roadmap과 Runbook을 작성해야 하는가

## 1.2 문서가 결정하지 않는 사항

다음 항목은 본 전략의 방향을 바꾸지 않는 세부 구현값이므로 후속 Runbook 또는 Decision에서 확정한다.

- Windows와 Ubuntu의 정확한 Partition 용량
- Secure Boot 유지 또는 해제 여부
- BitLocker와 Windows Fast Startup의 실제 상태
- Ubuntu 설치 이미지의 정확한 Build ID
- NVIDIA Driver의 최종 기준 Version
- Backup/Image 도구
- 신규 `host_id`와 `environment_id`
- 물리 Data Partition의 최종 Mount Point
- NoMachine 등 Remote Access의 최종 방식
- Docker Network Mode
- 외부 Autoware Docker의 구체적인 Interface
- 향후 추가 SSD의 정확한 제품과 용량

확인되지 않은 값을 추정으로 확정하지 않는다. 해당 값은 결정이 필요한 Gate에서 실측·검토하고 기록한다.

---

# 2. 배경과 출발점

## 2.1 기존 환경

기존 AVStack 검증환경은 Laptop 기반 Host에서 구축되었다.

```text
기존 Host: t15p-dev-ubt
OS: Ubuntu 22.04.5 LTS
GPU: NVIDIA RTX 3050 Laptop 4 GB
Graphics: PRIME on-demand
Display: NoMachine X11, DISPLAY=:1
NVIDIA Driver: 580.159.03
```

기존 환경에서는 다음을 실제로 확인했다.

- MORAI Launcher와 SIM 실행
- Scenario Runner 실행
- Built-in XOSC Scenario 실행
- ROS 2 Humble Host 통신
- MORAI ROS 2 Native 상태 수신과 차량 제어
- Scenario Runner Python API의 Python 3.13 재빌드 Package Import
- Vendor Communication 및 Evidence 동결
- Gate, Issue, Decision, Session Report 기반 운영

또한 다음 문제와 해결 경험을 축적했다.

- Scenario Runner의 Native Library 누락
- 소형 GPU의 대형 Map VRAM 부족
- Scenario Runner GUI Renderer 문제
- MORAI SIM Window Resize 불안정
- `RMW_IMPLEMENTATION` 환경변수에 따른 Simulator Crash
- rosbridge가 공식 ROS 2 경로가 아님
- Python 3.7용 Protected API Runtime 소멸
- Vendor의 Python 3.13 재빌드 Package 활용
- SIM 설정창이 열려 있을 때 물리가 정지하는 동작

이 경험은 신규 Workstation 구축의 중요한 입력이지만, 기존 Host의 PASS 판정은 신규 Host에 승계하지 않는다.

## 2.2 신규 Workstation 도입 배경

신규 Workstation은 기존 Laptop의 GPU·Memory·확장성 제약을 해소하고, 다음 활동을 수행하기 위해 도입되었다.

- MORAI 대형 Map과 복합 Sensor 환경
- ROS 2·Autoware·Simulator 동시 실행
- 시나리오 자동 실행과 평가
- 대규모 Log·rosbag·Map 처리
- Docker 기반 환경 생성과 검증
- Local Autoware Test
- 외부 Autoware Docker 통합
- 향후 AI·멀티모달·기초모델 관련 연구
- 배포 가능한 Reference Environment 마련

## 2.3 현재 상태

신규 Workstation에는 현재 Windows 11 Pro for Workstations만 설치되어 있다.

Ubuntu, NVIDIA Linux Driver, ROS 2, MORAI, Docker 및 AVStack Runtime은 아직 설치하지 않았다.

현재 Storage는 Samsung 9100 PRO 2 TB 한 개이며, Windows를 보존한 상태에서 동일 SSD에 Ubuntu를 Partition 설치한다. 향후 추가 SSD를 구매할 계획이며, 그때 이번 구축에서 정리한 문서·Script·Manifest를 사용하여 Clean Rebuild를 수행한다.

---

# 3. 확정 Hardware와 초기 제약

## 3.1 확정 Hardware

| 구분 | 구성 |
|---|---|
| CPU | AMD Threadripper PRO 9975WX, 32 Core / 64 Thread |
| Cooler | SilverStone XE360-TR5 |
| Mainboard | ASUS PRO WS WRX90E-SAGE SE |
| Memory | Samsung DDR5 ECC Registered 64 GB × 4, 총 256 GB |
| GPU | ASUS TUF Gaming RTX 5090 OC 32 GB |
| System SSD | Samsung 9100 PRO 2 TB |
| PSU | SuperFlower 2200 W Titanium |
| Case | Fractal Design Define 7 XL |
| OS | Windows 11 Pro for Workstations |
| Wireless Adapter | TP-Link Archer TXE72E 계열 |
| Onboard Network | Mainboard 10 GbE Interface 및 BMC Management Interface |

Hardware는 이미 구매·납품 완료되었다. 본 전략은 Hardware 변경 권고가 아니라 현재 구성에서 안정적이고 재현 가능한 환경을 구축하는 데 집중한다.

## 3.2 신규 Host의 중요한 차이

신규 Workstation은 기존 Laptop과 다음 점에서 다르다.

- 내장 GPU와 NVIDIA GPU를 전환하는 PRIME 구조를 기본 전제로 하지 않는다.
- RTX 5090이 주 Display·Vulkan 장치가 된다.
- 기존 `__NV_PRIME_RENDER_OFFLOAD` 기반 Launcher 설정을 그대로 승계하지 않는다.
- 기존 `DISPLAY=:1`과 NoMachine 환경을 기본값으로 사용하지 않는다.
- 32 GB VRAM 환경에서 기존 대형 Map 문제를 다시 검증한다.
- Local Console 기준선을 먼저 확보한 후 Remote GUI를 추가한다.
- BIOS, BMC, ECC Memory, 대용량 PCIe·Storage 등 Workstation 관리 항목이 추가된다.
- 최신 GPU와 Vendor Unity/Vulkan Runtime의 Compatibility를 실측해야 한다.

## 3.3 Network Adapter 확인 원칙

Wireless Adapter의 실제 Chipset은 제품명이나 판매정보만으로 확정하지 않는다.

Ubuntu 설치 전후에 PCI ID와 실제 Kernel Driver를 확인하여 Host Manifest에 기록한다. `Intel AX210`이라고 가정한 상태로 Driver 전략을 고정하지 않는다.

> [!note] As-built 실측 (2026-07-27)
> 활성 Wireless = **MediaTek MT7921**(AzureWave 모듈, driver `mt7921e`, PCI `14c3:7922`) — **Intel AX210 아님**. 유선은 Intel X710 10GbE ×2(`i40e`, 현재 미결선). 본 §3.3이 예고한 위험(제품명으로 Chipset 단정 금지)이 실증되었다. 증거: `~/avstack/runs/asbuilt_20260727_152313.txt` ([WS]).

Network는 초기 Package 설치와 Vendor 인증에 필요한 핵심 선행조건이다. Wi-Fi가 즉시 동작하지 않을 경우를 대비하여 Windows에서 필요한 Package를 준비해 USB로 전달하는 Offline Bootstrap 경로를 별도 Runbook에 포함한다.

향후 안정적인 유선 Network가 제공되면 대용량 Data 전송과 ROS 2/DDS 운용의 기본 경로는 Ethernet을 우선한다.

---

# 4. 목표 역할과 성공의 정의

## 4.1 Reference Workstation

신규 Workstation은 다음 Native 구성의 기준 동작을 제공한다.

- Ubuntu Host
- NVIDIA Driver와 Vulkan/Xorg
- MORAI Launcher·SIM
- Scenario Runner
- ROS 2 Humble
- MORAI ROS 2 Message Workspace
- Python OpenSCENARIO API
- 기준 Map·Vehicle·Scenario
- Vehicle State 수신과 Control Command
- Log·Result 생성

Native 환경은 Docker와 외부 Integration 문제를 분리하기 위한 기술 기준선이다.

## 4.2 Simulator Build and Qualification Host

신규 Workstation은 다음 배포자산을 개발·검증하는 Host로 사용한다.

- Simulator Orchestration
- ROS 2 Adapter
- Health Check
- Simulator Self-Test
- Replay·Evaluation
- Dockerfile과 Compose
- Host Compatibility 정의
- Release 후보와 Known Limitation

## 4.3 Autoware Integration Testbed

신규 Workstation은 두 가지 Autoware 환경을 수용한다.

### Local Autoware Test Environment

사용자가 독립적으로 생성하고 고정 Version으로 유지하는 Test용 Autoware Container다.

목적:

- Simulator–Autoware Interface 조기 검증
- ROS 2 Topic, QoS, TF, Clock, Map, Vehicle Control 검증
- 외부 개발자 일정과 무관한 Closed-loop Test
- 외부 Container Integration 문제의 비교 기준
- Autoware 구조 및 운용 방법의 자체 이해

Local 환경은 외부 개발자의 생산용 Autoware를 대체하는 것이 아니다.

### External Autoware Integration Environment

담당 개발자가 제공하는 Autoware Docker를 연결한다.

외부 Image 내부 구현에 의존하기보다 명시적인 Interface Contract와 Acceptance Test를 기준으로 통합한다.

## 4.4 장기적인 성공조건

이번 환경 구축은 다음 단계로 성숙한다.

```text
Planned Environment
→ Installed Environment
→ Qualified Native Reference Environment
→ Container-integrated Environment
→ Autoware-integrated Environment
→ Reproduced Environment on Second SSD
→ Distributable Reference Environment
```

Ubuntu가 부팅되고 Package가 설치된 상태만으로는 Reference Environment로 승인하지 않는다.

---

# 5. Non-goals

본 전략의 초기 범위에는 다음을 포함하지 않는다.

- 현재 Hardware의 재구매 또는 즉각적인 확장
- 기존 Laptop 환경의 폐기
- 처음부터 MORAI 전체를 Docker에 포함
- 외부 Autoware 내부 개발
- Autoware 전체 기능과 모든 Sensor의 즉시 통합
- Vendor Binary·License·대용량 Map의 Git 배포
- `oss3-mgmt` 문서체계 개편
- GitHub Issues/Projects의 전면 전환
- Argos EOS 등 범용 Engineering 방법론 개발
- AVStack 전체 Repository 경계의 즉시 재편
- 실제 설치 전 Reference Version 선언

이 항목들은 필요성이 실증된 뒤 별도 Decision과 Roadmap으로 다룬다.

---

# 6. 핵심 설계 철학과 운영원칙

## 6.1 Reference Environment, not One-time Installation

이번 작업은 한 번 실행되는 개인 설정이 아니라 다음 사람 또는 미래의 동일 사용자가 다시 만들 수 있는 기준환경을 구축하는 일이다.

환경 완성에는 실행 가능한 System과 함께 다음이 포함된다.

- Version
- Configuration
- Decision
- Runbook
- Qualification
- Evidence
- Known Limitation
- Rollback
- Rebuild 정보

## 6.2 Reproducibility before Convenience

일회성 수동 조작으로 빠르게 동작시키는 것보다, 재실행 가능한 절차와 자동화를 우선한다.

GUI 조작이 불가피한 경우에도 다음을 기록한다.

- 조작 위치
- 입력값
- 선행조건
- 기대 상태
- 실패 분기
- 확인 Evidence

## 6.3 Recovery and Rebuild are Different

### Recovery

현재 SSD와 환경을 이전 정상 상태로 복구하는 능력이다.

예:

- Windows Recovery
- Bootloader 복구
- Package Rollback
- Configuration 복원
- Snapshot 또는 Disk Image
- 이전 Container Image로 복귀

### Rebuild

새 SSD 또는 다른 호환 Host에 환경을 처음부터 다시 구성하는 능력이다.

예:

- OS Clean Install
- Package와 Driver 재설치
- Repository Clone
- Vendor Asset 복원
- Configuration 적용
- 동일 Qualification 재수행

Disk Clone 또는 Image만으로는 Reproducibility를 입증하지 않는다.

## 6.4 Native as the Technical Baseline

MORAI·Scenario Runner·ROS 2·Python API의 Native 동작을 먼저 확보한다.

Container 환경에서 문제가 발생하면 동일 Test를 Native에서 수행하여 다음을 구분한다.

- Host 또는 Driver 문제
- Vendor Runtime 문제
- Container Runtime 문제
- Network Namespace 문제
- DDS Discovery 문제
- Volume·Permission 문제
- Application Integration 문제

## 6.5 Containerize by Boundary

모든 구성요소를 하나의 Image에 넣지 않는다.

다음 경계를 기준으로 분리한다.

1. Hardware·Firmware
2. Ubuntu·Kernel·NVIDIA Driver
3. Vendor Simulator Runtime
4. ROS 2·Adapter·Orchestrator
5. Local/External Autoware
6. Replay·Evaluation
7. Data·Map·Log·Model

Containerization은 격리와 배포의 수단이지, 확인되지 않은 Host 의존성을 숨기는 수단이 아니다.

## 6.6 Evidence before Completion

작업 완료는 설명이나 육안 인상으로 선언하지 않는다.

위험도와 Stage에 맞는 Evidence를 남긴다.

예:

- Version 출력
- Configuration
- PCI ID
- `nvidia-smi`
- Vulkan Device
- ROS 2 Topic과 Frequency
- TF Tree
- Scenario Lifecycle
- Control Response
- Log
- Result
- Checksum
- Screenshot
- Review Record

## 6.7 Preserve Existing Knowledge, Requalify on New Host

기존 `avstack-control`의 Script, Runbook, Issue, Decision, Vendor Evidence 및 실험 결과를 활용한다.

그러나 기존 Laptop의 PASS는 신규 Workstation에 승계하지 않는다.

기존 정보는 다음 중 하나로 분류한다.

- 그대로 재사용할 원칙
- 수정 후 재사용할 Script
- 신규 Host에서 재검증할 Test
- 기존 Host 전용 설정
- Historical Evidence
- 폐기 후보

## 6.8 Definition in Git, Runtime outside Git

기존의 다음 원칙을 유지한다.

> 사람이 작성·결정한 정의는 Git에 두고, 실행으로 재생성 가능한 Runtime은 Git 밖에 둔다.

### Git 관리 대상

- Strategy
- Runbook
- Script
- Environment Definition
- Manifest
- Interface Contract
- Decision
- Qualification 판정
- Evidence Index
- Release Metadata

### Git 외부 대상

- MORAI Binary
- Vendor Package 원본
- 대용량 Map
- rosbag
- Runtime Log
- Build Output
- Container Cache
- Model·Dataset
- License·Credential

대외 주장이나 장기 Qualification에 필요한 Evidence는 민감정보를 제거한 뒤 제한적으로 `[CONTROL]`에 동결할 수 있다.

## 6.9 One Source of Truth

동일 상태를 여러 문서에서 독립적으로 판정하지 않는다.

- 기술 판정: `[CONTROL]`의 승인된 Record
- Runtime 실체: `[WS]`
- Scenario 정의: `[SCEN]`
- 평가 Code: `[EVAL]`
- 과제 계획·상위 상태: `[MGMT]`

요약문서는 정본을 참조하며 자체 판정을 만들지 않는다.

## 6.10 Preserve before Evolve

새로운 방식이 더 좋아 보여도 기존 결과를 무기한 수정하거나 삭제하지 않는다.

- 적용 전 문서는 Draft로 관리한다.
- 실제 적용 후 Baseline을 만든다.
- 구조가 크게 달라지면 다음 Version을 만든다.
- 기존 Version의 한계와 전환 이유를 남긴다.
- 미적용 초안을 완료된 Release로 선언하지 않는다.

## 6.11 Human Accountability and Independent Review

AI 도구는 분석, 구현, 문서화 및 Test를 지원한다. 다음 책임은 사람에게 남는다.

- Partition·Bootloader 변경 승인
- BIOS·Firmware 변경 승인
- OS·Kernel·NVIDIA Driver 기준 변경
- Vendor License와 Secret 처리
- 파괴적 Data 작업
- Interface Breaking Change
- Reference Environment 승인
- 외부 Release 승인

중요 변경에서는 구현자와 Reviewer를 분리한다.

---

# 7. Target Environment Architecture

## 7.1 전체 Layer

```text
┌──────────────────────────────────────────────┐
│ Replay / Evaluation / Qualification          │
├──────────────────────────────────────────────┤
│ Local Autoware / External Autoware            │
├──────────────────────────────────────────────┤
│ ROS 2 / Python API / Integration Services     │
├──────────────────────────────────────────────┤
│ MORAI SIM / Scenario Runner / Vendor Assets   │
├──────────────────────────────────────────────┤
│ Ubuntu / Kernel / NVIDIA / Vulkan / Network   │
├──────────────────────────────────────────────┤
│ Windows Recovery / Boot / Storage             │
├──────────────────────────────────────────────┤
│ WRX90 Workstation Hardware / Firmware         │
└──────────────────────────────────────────────┘
```

하위 Layer가 검증되지 않은 상태에서 상위 Layer의 문제를 해결하려 하지 않는다.

## 7.2 Windows 역할

Windows는 다음 목적으로 보존한다.

- 출고 및 초기 Hardware 상태 보존
- Vendor Utility와 Firmware 관리
- Hardware 진단
- Ubuntu 설치 실패 시 복구
- Windows 전용 업무 또는 도구
- 설치 Package와 Offline 자료 준비

AVStack의 기준 개발환경은 Ubuntu로 통일한다.

## 7.3 Ubuntu 역할

Ubuntu는 다음의 기준 Host다.

- MORAI Native
- Scenario Runner
- ROS 2 Humble
- Python API
- Docker
- Local Autoware Test
- External Autoware Integration
- Replay·Evaluation
- AVStack 개발과 Qualification

기준 OS는 기존 Vendor 및 ROS 2/Autoware 호환성을 고려하여 Ubuntu 22.04 LTS 계열을 사용한다. Point Release와 Kernel·Driver 조합은 설치 전 Baseline 단계에서 확정한다.

## 7.4 Display 전략

신규 Host에서는 Local Physical Console의 Xorg/Vulkan 동작을 먼저 기준선으로 확보한다.

Remote Access는 Local 기준선 통과 후 추가한다.

다음 순서를 따른다.

```text
Local Console Qualification
→ RTX 5090 Display/Vulkan Qualification
→ MORAI Native GUI Qualification
→ Remote Access 추가
→ Local과 Remote 결과 비교
```

기존 Laptop의 `DISPLAY=:1`과 PRIME Offload는 신규 Host의 기본 설정이 아니다.

## 7.5 Storage 논리경로

기존 Script와 Runbook의 호환성을 위해 다음 논리경로를 유지하는 것을 기본방향으로 한다.

```text
~/avstack-control
~/avstack
```

물리 Storage가 현재 System SSD인지 향후 Data SSD인지와 관계없이 Script가 참조하는 논리경로는 안정적으로 유지한다.

향후 추가 SSD 도입 시 물리 Mount와 Bind Mount 또는 동등한 방식으로 논리경로를 유지하는 방안을 Runbook에서 결정한다.

---

# 8. Windows·Ubuntu·Storage 전략

## 8.1 현재 단일 SSD 운영

초기 환경은 2 TB System SSD 한 개에서 구성한다.

원칙:

- 기존 EFI·Windows Recovery 영역을 보존한다.
- Windows Partition 축소 전 Recovery와 Disk 상태를 확보한다.
- Ubuntu 설치 전 BitLocker·Secure Boot·Fast Startup 상태를 확인한다.
- 정확한 Partition 크기는 Windows 실제 사용량과 향후 Data 요구를 확인한 뒤 결정한다.
- Ubuntu Runtime Data는 가능한 한 Linux File System에 둔다.
- NTFS 공유영역은 전달용 보조수단으로만 사용한다.

## 8.2 Backup 단계

Backup은 하나의 방법으로 해결하지 않는다.

### 전체 Disk/OS Recovery

Windows와 Partition 손상에 대비한다.

### Configuration Recovery

Git, Manifest, Package List 및 Configuration으로 복구한다.

### Runtime Data Backup

Map, Scenario, 중요 rosbag 및 Result를 별도로 관리한다.

### Vendor Asset Backup

재다운로드 가능 여부, License 조건 및 Checksum을 기록한다.

## 8.3 Environment Lifecycle

Environment 상태는 다음처럼 관리한다.

```text
Planned
→ Installed
→ Qualified
→ Accepted Reference
→ Superseded
→ Archived
```

실제 Qualification 전에는 Version을 `Reference v1`로 확정하지 않는다.

## 8.4 Second SSD Clean Rebuild

추가 SSD가 도입되면 다음 절차로 재현성을 검증한다.

1. 기존 Environment Manifest 동결
2. Vendor Asset Inventory 확인
3. 새 SSD에 Ubuntu Clean Install
4. Repository Clone
5. Script와 Runbook으로 환경 재구축
6. Asset 복원과 Checksum 확인
7. 동일 Qualification 수행
8. 두 환경 차이 기록
9. 숨은 수동 의존성 제거
10. 새 환경 승인 후 기존 Ubuntu Partition 처리 결정

Clone은 긴급 복구나 비교용으로 사용할 수 있지만 공식 Rebuild 증거로 사용하지 않는다.

---

# 9. 기존 자산 활용과 Migration 원칙

## 9.1 Asset 분류

기존 Laptop과 Repository 자산을 다음으로 분류한다.

| 분류 | 의미 |
|---|---|
| Reuse as-is | Host와 무관한 문서·정의·Test |
| Adapt and reuse | Host 경로·GPU·Display 등을 수정해야 하는 Script |
| Requalify | 기능은 같지만 신규 Host에서 다시 검증해야 하는 항목 |
| Redownload | 공식 배포처에서 다시 받을 수 있는 Package |
| Restore | Vendor 제공본·Map·Scenario 등 복원할 자산 |
| Regenerate | Build·Cache·Runtime Output |
| Preserve as evidence | 과거 장애·실측·Vendor Communication |
| Retire candidate | 구 Python 3.7 환경, 폐기 경로, 불필요한 우회 |
| Secret/License | 별도 보안경로, Git 제외 |

## 9.2 반드시 Inventory할 항목

- MORAI Launcher와 SIM Version
- Scenario Runner Version
- Python 3.13 API 원본 Package와 Checksum
- Package에 동봉된 Requirements
- MORAI ROS 2 Message Repository와 Commit/Tag
- Map과 Scenario 목록
- User/License/Account 재인증 방법
- Launcher·Diagnostic Script
- Conda Environment
- Existing Evidence
- Vendor Communication
- 기존 Host 전용 Configuration
- 폐기 예정 Python 3.7 환경

## 9.3 이관 원칙

- 전체 `~/avstack`을 무조건 복사하지 않는다.
- 재생성 가능한 Build Output과 Cache는 이관하지 않는다.
- Vendor Asset은 원본과 설치본을 구분한다.
- Checksum을 생성하여 복사 후 검증한다.
- Secret과 License는 일반 Archive에 포함하지 않는다.
- 신규 Host 경로를 기존 Home 경로에 강제로 맞추지 않는다.
- 재현용 Conda YAML에서 절대 `prefix`를 제거한다.

---

# 10. Native Reference 전략

## 10.1 기존 Stage와 신규 Host 관계

기존 Stage는 기술적으로 무엇을 검증해야 하는지 알려주는 자산이다.

신규 Host에서는 다음을 다시 수행한다.

- GPU/Vulkan
- MORAI Launcher/SIM
- Scenario Runner
- Built-in Scenario
- ROS 2 Host
- MORAI ROS 2 Native
- Python API
- Boundary Detection
- Batch·Reproducibility

기존 Stage ID와 결과는 보존한다. 신규 Host의 판정은 Host/Environment 식별자를 포함하는 별도 Qualification Record로 분리하는 방향을 후속 ADR에서 확정한다.

## 10.2 NVIDIA·Vulkan 기준

확인 대상:

- GPU PCI Device
- NVIDIA Driver
- Display Renderer
- Vulkan Physical Device
- GPU Memory
- Local GUI
- Container GPU Access
- 재부팅 후 일관성

RTX 5090의 성능이 충분하다는 사실과 Vendor Runtime Compatibility는 별개다. 반드시 실제 MORAI Scene과 Scenario로 확인한다.

## 10.3 MORAI와 Scenario Runner

확인 대상:

- Launcher
- SIM
- Map Load
- Vehicle Spawn
- Scenario Runner
- Built-in Scenario
- 정상 종료
- 대형 Map
- Window Resize
- GUI Rendering
- Log 위치

기존 Laptop의 PRIME Wrapper는 신규 Host에 맞게 분기 또는 대체한다.

## 10.4 ROS 2 Native

기존 실측을 신규 Host의 Regression Test로 활용한다.

필수 확인:

- ROS 2 Humble
- MORAI Message Workspace
- `ROS_LOCALHOST_ONLY=0`
- Simulator Process에서 `RMW_IMPLEMENTATION` 미설정
- ROS2 Connect
- 설정창 종료
- `/ego_vehicle_status`
- Message Type
- Frequency
- `CtrlCmd`
- 차량 반응
- Stop 동작

rosbridge는 운영경로로 채택하지 않는다.

## 10.5 Python API

현재 기준:

```text
Python 3.13
sourcedefender 16.0.65
Vendor rebuilt API
gRPC 127.0.0.1:7789
```

확인 대상:

- Environment 재생성
- Protected Module Import
- Client/Importer 생성
- Scenario Import
- Start/Stop
- `get_stop_status`
- Callback
- Qt Event Loop 요구
- Scenario Boundary
- Log/Result 생성

구 Python 3.7 환경은 Python 3.13 경로가 신규 Host에서 PASS한 뒤 폐기 여부를 결정한다.

---

# 11. Docker 및 배포 전략

## 11.1 Native 우선

Native Qualification이 완료되기 전에 Full Container 환경을 공식 목표로 삼지 않는다.

## 11.2 Hybrid Simulator Distribution

첫 배포 형태의 기본 후보는 Hybrid다.

```text
Host:
- Ubuntu
- NVIDIA Driver
- Vulkan/Xorg
- MORAI SIM / Scenario Runner

Container:
- Orchestrator
- ROS 2 Adapter
- Health Check
- Self-Test
- Evaluation
- Local Autoware Test
```

장점:

- Vendor Runtime 안정성 유지
- License·GUI·GPU 문제 분리
- 변경이 잦은 사용자공간의 재현성 확보
- 외부 Autoware Container 연결 용이

## 11.3 Full Simulator Container

장기 Candidate로 유지한다.

다음을 확인하기 전에는 공식 지원형태로 승인하지 않는다.

- Vendor License와 재배포 권한
- GPU/Vulkan
- GUI Session
- Account·License Binding
- ROS 2/DDS
- gRPC
- Data Volume
- Performance
- Native 대비 기능·결과 동등성
- Vendor Support 범위

## 11.4 Host Compatibility Contract

Docker 배포는 Host 의존성을 제거하지 않는다.

배포물에는 최소한 다음을 명시한다.

- 지원 Host OS
- Kernel/Driver 범위
- NVIDIA GPU와 VRAM
- Docker와 NVIDIA Container Runtime
- Display 방식
- Network 요구
- Port
- Vendor Asset 요구
- 지원 Map·Scenario
- Known Limitation

## 11.5 Data와 Image 분리

Container Image에 다음을 직접 포함하지 않는 것을 원칙으로 한다.

- License
- Secret
- 대용량 Map
- rosbag
- Runtime Result
- 사용자별 설정
- 재배포 제한 Vendor Asset

Image, Asset Bundle, Data Volume 및 Secret 공급을 분리한다.

---

# 12. Simulator Self-Test

Simulator Self-Test는 별도 Product Profile이 아니라 Native·Hybrid·Full Container 환경에 공통 적용하는 Acceptance Suite다.

최소 Test Scope:

- Launcher/Runtime Startup
- Map Load
- Ego Spawn
- Scenario Load
- Scenario Start/Stop
- gRPC/API
- ROS 2 Topic
- Message Type/QoS
- Simulation Clock
- Vehicle State
- Control Command
- Vehicle Response
- Log/Result
- Cleanup
- Repeated Execution

동일 Test를 Native와 Container에 적용하여 환경 차이를 확인한다.

정확한 반복횟수, 허용오차 및 PASS 기준은 Qualification Plan에서 정의한다.

---

# 13. Autoware 통합 전략

## 13.1 Local Autoware Test Environment

Local 환경은 다음 원칙을 따른다.

- 고정 Release 또는 Commit
- Runtime과 Development Image 분리 가능
- 최소 Map·Vehicle·Sensor Configuration
- Simulator Integration에 필요한 범위 우선
- 외부 팀의 제품 성능을 대신 평가하지 않음
- 반복 가능한 Smoke/Closed-loop Test 제공

## 13.2 External Autoware Integration

외부 개발자의 Container는 Black-box Integration 대상으로 취급한다.

필요정보:

- Image Tag와 Digest
- ROS 2 Distribution
- RMW/DDS
- `ROS_DOMAIN_ID`
- Topic
- Message Type
- QoS
- TF
- Clock
- Map
- Vehicle State
- Control Output
- Startup/Health/Lifecycle
- Log와 Error

## 13.3 공통 Interface Contract

Local과 External 환경은 가능한 한 동일한 Contract와 Acceptance Test를 사용한다.

Contract는 최소한 다음을 포함한다.

- Topic
- Service/Action
- QoS
- Frame
- Unit
- Timestamp
- Clock
- Control
- Vehicle State
- Lifecycle
- Health
- Error Handling

Breaking Change는 별도 Decision과 재Qualification을 요구한다.

---

# 14. Replay·Evaluation 전략

Evaluation을 Simulator Runtime과 분리한다.

목적:

- Simulator 없이 Result 재평가
- rosbag·eventlog·statelog Replay
- KPI 재계산
- Regression 비교
- CI 연계
- Report 재생성
- 다른 Host에서 동일 평가 수행

기존 `[EVAL]` 계획과의 최종 경계는 평가 Framework 구현 착수 시 기존 ADR-008과 Repository Boundary를 기준으로 확정한다.

---

# 15. Qualification, Evidence, Rollback

## 15.1 Qualification 단위

최소 식별정보:

- `host_id`
- `environment_id`
- 대상 Stage 또는 Capability
- Version
- Configuration
- Test 입력
- Evidence
- 판정
- Known Limitation
- 판정자
- 날짜

기존 `records/stages.tsv`의 Project 이력을 보존하면서 신규 Host별 Qualification을 분리할 Schema는 별도 ADR에서 확정한다.

## 15.2 PASS 비승계 원칙

다음은 서로 다른 판정이다.

- 기존 Laptop Native PASS
- 신규 Workstation Native PASS
- 신규 Workstation Hybrid Container PASS
- Local Autoware PASS
- External Autoware PASS
- Second SSD Rebuild PASS

한 환경의 PASS가 다른 환경으로 자동 승계되지 않는다.

## 15.3 변경 후 재Qualification

다음 변경은 영향분석 후 필요한 Test를 다시 수행한다.

- BIOS/Firmware
- Kernel
- NVIDIA Driver
- Ubuntu Point Release
- ROS 2/RMW
- Vendor SIM
- Scenario Runner
- Message Package
- Python API
- Docker Base Image
- Interface Contract
- Map·Vehicle Configuration
- Local/External Autoware Image

## 15.4 Rollback

각 변경은 가능한 범위에서 다음을 갖는다.

- 변경 전 Version
- Backup
- Revert 방법
- Boot/Recovery 경로
- 이전 Image/Digest
- 변경 전 Manifest
- Rollback 후 확인 Test

---

# 16. 작업 및 Review 역할

본 문서에서는 범용 AI Governance를 만들지 않는다. 신규 Workstation 구축에 필요한 최소 역할만 적용한다.

## 16.1 Claude Code

- `[CONTROL]` 로컬 작업의 주 실행자
- Script·Runbook·Manifest 구현
- 명령 실행과 Evidence 수집
- 변경 Diff 정리
- Session Handover 갱신

## 16.2 Codex

- 독립 Review
- Test·Regression 재실행
- Script와 문서의 불일치 확인
- 누락된 위험·Rollback·Evidence 확인

동일 변경을 구현한 Context와 독립된 Context를 사용한다.

## 16.3 ChatGPT

- 전략과 Architecture Review
- 범위·논리·정합성 검토
- Risk와 Acceptance 판단안
- 문서 간 충돌 검토

## 16.4 Human Project Owner

- 최종 Scope
- Partition·Firmware·Driver 승인
- 파괴적 명령 승인
- Vendor License 및 Secret 처리
- Qualification 승인
- Reference Environment 승인
- 외부 Release 승인

---

# 17. 단계별 추진전략

본 절은 상세 Roadmap을 대신하지 않으며, 후속 Roadmap이 따라야 할 상위 순서만 정의한다.

## Phase A — Existing Asset Assessment

- 기존 Repository·Runtime·Vendor Asset Inventory
- 재사용·이관·재생성·폐기 분류
- Checksum과 License 확인
- 기존 Host 종속사항 식별

## Phase B — Windows Baseline and Recovery

- Hardware/Firmware Inventory
- Disk/EFI/Recovery 상태
- BitLocker·Secure Boot·Fast Startup
- Recovery Media/Image
- 변경 전 승인

## Phase C — Ubuntu Host Foundation

- Dual Boot
- Ubuntu Base
- Network
- Local Console/Xorg
- NVIDIA/Vulkan
- Storage
- Git/SSH
- Host Manifest

## Phase D — Native AVStack Reference

- Runtime Layout
- MORAI
- Scenario Runner
- Built-in Scenario
- ROS 2 Native
- Python API
- Simulator Self-Test

## Phase E — Reference Qualification

- 기준 Test
- 반복 실행
- Evidence
- Known Limitation
- Environment Manifest
- Accepted Reference 여부 판정

## Phase F — Local and External Autoware

- Local Autoware Test
- Interface Contract
- Closed-loop Test
- External Container Integration

## Phase G — Docker Distribution

- Hybrid
- Self-Test
- Host Contract
- Image Digest
- Release Candidate
- Full Container Feasibility

## Phase H — Second SSD Rebuild

- Clean Install
- Script·Runbook 적용
- Asset 복원
- 동일 Qualification
- Difference Report
- Reproducibility 판정

---

# 18. 미결정사항과 결정 시점

| 항목 | 현재 상태 | 결정 시점 |
|---|---|---|
| Partition 용량 | TBD | Windows Baseline 후, Dual Boot Runbook 승인 전 |
| Secure Boot | **disabled** (As-built 2026-07-27) | NVIDIA Driver 전략 결정 시 |
| NVIDIA Driver Version | TBD | Ubuntu Host Foundation Preflight |
| Wireless Chipset/Driver | **MediaTek MT7921 / mt7921e** (As-built 2026-07-27) | Windows/Ubuntu Hardware Inventory |
| Host ID | TBD | Host Manifest 생성 시 |
| Environment ID | TBD | Installed Environment 생성 시 |
| Backup 도구 | TBD | Windows Baseline Runbook |
| Physical Data Mount | TBD | Storage 설계 및 향후 SSD 계획 검토 시 |
| Remote Access | TBD | Local Console Qualification 후 |
| Docker Network Mode | TBD | Hybrid PoC 전 |
| Full Container | Candidate | Hybrid 및 License 검증 후 |
| External Autoware Contract | 미수령 | 외부 Image 수령 전 Integration Gate |
| Host Qualification Schema | ADR 필요 | 신규 Host 첫 공식 PASS 기록 전 |
| Python 3.7 환경 폐기 | 보류 | Python 3.13 Stage PASS 후 |

---

# 19. 기존 문서와의 관계

## 19.1 유지

- `CLAUDE.md`의 세션·안전·Evidence 규칙
- `PROJECT_STATUS.md`의 현재 상태 인덱스 역할
- `records/*.tsv`의 기존 이력
- `runbooks/repo_boundaries.md`의 5개 영역
- Vendor Communication 관리
- 기존 Session Report와 Evidence

## 19.2 이후 정합화

본 전략 승인 후 다음 문서를 최신 사실과 신규 Host 구조에 맞게 조정한다.

- `PROJECT_STATUS.md`
- `runbooks/integrated_roadmap.md`
- `runbooks/stage03_5_checklist.md`
- `api_contract.md`
- `CLAUDE.md`
- 필요한 ADR과 Record Schema

## 19.3 변경하지 않음

본 전략은 다음을 재설계하지 않는다.

- `[MGMT] oss3-mgmt`
- 기존 Item Ontology
- Dashboard/Obsidian Pipeline
- `[SCEN]`과 `[EVAL]`의 기존 예정 Boundary
- GitHub Issues/Projects 운영체계

---

# 20. 후속 산출물

본 전략이 Accepted 상태가 되면 다음 순서로 문서를 작성한다.

1. `new_workstation_bootstrap_roadmap.md`
2. `existing_environment_asset_migration.md`
3. `windows_baseline_and_recovery.md`
4. `install_ubuntu_dualboot.md`
5. `qualify_network_and_remote_access.md`
6. `install_and_qualify_nvidia.md`
7. `bootstrap_avstack_workspace.md`
8. `install_and_qualify_morai_native.md`
9. `qualify_ros2_native.md`
10. `qualify_python_api.md`
11. `qualify_simulator_self_test.md`
12. `build_local_autoware_test.md`
13. `integrate_external_autoware.md`
14. `build_simulator_distribution.md`
15. `rebuild_on_second_ssd.md`
16. Host/Environment Manifest와 Qualification Record

문서명은 실제 Repository 구조 검토 후 일부 조정할 수 있으나 책임 분리는 유지한다.

---

# 21. 전략 문서 완료 기준

본 문서는 다음을 만족할 때 Accepted 상태로 전환할 수 있다.

- 신규 Workstation의 목적과 역할이 명확하다.
- 확정 Hardware와 현재 상태가 정확하다.
- 기존 Host의 지식 활용과 PASS 비승계가 구분된다.
- Windows·Ubuntu·Storage 전략이 명확하다.
- Native·Docker·Autoware 관계가 논리적으로 연결된다.
- Recovery와 Rebuild가 구분된다.
- Qualification·Evidence·Rollback 원칙이 정의된다.
- 기존 5개 영역과 충돌하지 않는다.
- 미결정사항의 결정 시점이 명시된다.
- 후속 Roadmap과 Runbook으로 분해 가능하다.
- 사용자 검토와 승인을 받는다.

---

# 22. 전략 요약

본 전략의 핵심은 다음과 같다.

> 기존 AVStack 환경에서 확보한 실측 지식과 통제체계를 활용하되, 신규 WRX90 Workstation을 독립적으로 Qualification하는 Ubuntu 기반 Native Reference Environment로 구축한다.

> 현재 단일 SSD에서는 Windows를 보존한 Dual Boot 환경으로 시작하고, 설치·설정·Evidence를 체계화한다. 향후 추가 SSD에서는 Clone이 아니라 Clean Rebuild를 수행하여 Reproducibility를 검증한다.

> Native Simulator 기준선을 먼저 확립하고, 이를 바탕으로 Hybrid Docker 배포, Local Autoware Test, External Autoware Integration 및 Replay/Evaluation 환경으로 단계적으로 확장한다.

> 모든 완료 판정은 Version, Test, Evidence, Known Limitation 및 Rollback을 포함하며, 고위험 변경과 Reference Environment 승인은 사람이 최종 책임진다.
