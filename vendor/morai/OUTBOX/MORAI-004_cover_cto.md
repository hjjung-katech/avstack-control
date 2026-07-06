# MORAI 과제협조요청 커버 (내부 ID: MORAI-004 / 수신: CTO / 관련: AVS-006, AVS-007)

<!-- INTERNAL: CTO(전형석 상무) 수신 커버 메일. 첨부 3건(본문 순서) =
     1) KATECH-API-PY37_기술상세.pdf (AVS-006/MORAI-002),
     2) KATECH-SIM-ROS2_기술상세.pdf (AVS-007/MORAI-001),
     3) KATECH_evidence_20260706.zip (인용 evidence 7건).
     발송 시 제목의 "(내부 ID...)"·INTERNAL 블록 제거. SENT 동결 시 발송본을 SENT/로. -->

전형석 상무님,

안녕하세요. 한국자동차연구원 정호정 책임연구원입니다.

3세부에서 제가 올해부터 MORAI SIM 기반 시나리오 검증을 담당하고 있습니다.
진행 중에 기술 이슈 2건이 있어 연락드립니다. 상세 내용과 재현 로그는 정리해서 첨부했고, 여기서는 요점만 말씀드릴게요.

첫 번째는 OpenSCENARIO API 건입니다 (첨부 1, Ref: KATECH-API-PY37).
API 22.R3이 sourcedefender(Python 3.7 기준)로 암호화되어 있는데, 3.7용 런타임이 PyPI에서 내려간 상태라 import 자체가 안 됩니다.
시나리오 배치 실행·자동 평가 작업의 전제라 올해 산출물 일정상 가장 급합니다. 3.7 호환 sourcedefender 휠을 보내주시거나,
더 최신 API 배포본이 있다면 그쪽을 안내해 주시면 바로 해결됩니다.

두 번째는 SIM 26.R1.H3의 ROS2 연동입니다 (첨부 2, Ref: KATECH-SIM-ROS2).
ROS2 Native는 host ROS2를 소싱한 상태로 기동하면 SIM이 startup에서 종료되고(std::bad_cast), rosbridge는 ROS1 헤더(header.seq) 문제로
데이터 수신이 0입니다. 원인 계층까지는 저희가 분석해 놓았으니, 이 건은 기술 담당 엔지니어 한 분만 연결해 주시면 되겠습니다.
추가 로그나 재현 환경은 바로 드릴 수 있습니다.

첨부:
1) KATECH-API-PY37_기술상세.pdf
2) KATECH-SIM-ROS2_기술상세.pdf
3) KATECH_evidence_20260706.zip

과제 일정이 있어 7월 10일(이번주)까지 담당 연결이나 1차 회신을 받을 수 있으면 좋겠습니다.
필요하시면 30분 정도 짧게 콜로 설명드려도 됩니다.

감사합니다.
정호정 배상
