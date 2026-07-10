# MORAI 재회신 이메일 본문 (내부 ID: MORAI-001 후속 / 수신: 양종범 / 관련: AVS-007, AVS-006)

<!-- INTERNAL: 2026-07-08 양종범님 회신에 대한 스레드 답장(Re: [과제협조] ... Ref KATECH-API-PY37 / KATECH-SIM-ROS2).
     첨부(본문 순서) = 1) KATECH-SIM-ROS2_검증결과_기술상세 (MORAI-001_avs007_t24_followup.md 기반, 지난번처럼 PDF 변환),
     2) KATECH_evidence_20260710.zip (동결 evidence 4건).
     이슈1(API 재빌드) 문단은 리마인드 성격 — 이미 수령했거나 별도 스레드로 온 경우 삭제.
     발송 시 INTERNAL 블록 제거, SENT 동결 시 발송본을 SENT/로. -->

양종범님,

안녕하세요. 한국자동차연구원 정호정입니다. 빠른 확인과 회신 감사드립니다.

두 번째 이슈(SIM 26.R1.H3 ROS2 연동, Ref: KATECH-SIM-ROS2)에 대해, 권장해 주신 대로 저희 환경 설정을 재점검하고 결과를 공유드립니다.

ROS2용 morai_msgs를 SIM 버전과 정합한 공식 리포 태그 26.R1로 빌드해 소싱했고, 소싱이 SIM 프로세스에 실제 반영됐음을 프로세스 environ 캡처로 확인한 상태에서 재시험했습니다.
아쉽게도 결과는 두 경로 모두 기존과 동일했습니다.

- Native: 소싱 상태에서도 SIM이 startup에서 동일하게 종료됩니다(std::bad_cast). 크래시 지점이 메시지 사용 이전인 rcl/rmw 초기화 계층입니다.
- rosbridge: 토픽 생성까지는 되지만 SIM 발행이 header.seq 필드 불일치로 전부 거부됩니다(15분간 약 13.9만 건). 거부 목록에 morai_msgs가 아닌 표준 tf2_msgs도 포함되어 있어, msgs 소싱·버전과는 무관해 보입니다.

상세 조건·로그·분석은 첨부 1(검증 결과 기술상세)과 첨부 2(증거 로그 4건)로 정리했습니다.

확인 부탁드리고 싶은 것은 세 가지입니다.

1. 내부에서 재현·확인하셨을 때의 환경 정보(host ROS2 버전, rosbridge 버전, morai_msgs 소싱 방법) — 저희 결과와의 차이를 특정하고자 합니다.
2. Native 경로의 호환 검증된 host ROS2/Fast-DDS 버전 조합, 또는 standalone ros2cs 빌드 제공 가능 여부.
3. rosbridge 경로에서 SIM이 ROS2 헤더 포맷(seq 없음)으로 발행하는 설정이 있는지 여부.

필요하시면 원격으로 재현 과정을 바로 보여드릴 수 있습니다.

아울러 첫 번째 이슈(OpenSCENARIO API, Ref: KATECH-API-PY37)의 Python 업그레이드 재빌드 건은 안내해 주신 일정(금일) 기준으로 대기 중입니다. 준비되는 대로 전달해 주시면 바로 검증하겠습니다.

감사합니다.
정호정 드림

첨부:
1) KATECH-SIM-ROS2_검증결과_기술상세.pdf
2) KATECH_evidence_20260710.zip (로그 4건)
