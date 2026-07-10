# MORAI 3차 회신 이메일 본문 — 해결 보고 (내부 ID: MORAI-001 후속2 / 수신: 양종범)

<!-- INTERNAL: 2026-07-10 2차 회신(환경 정보+직접 실행 재확인 요청+API py3.13 납품)에 대한 결과 공유.
     스레드 동일. 근거: runbooks/t24_vendor_diag_verification.md §6 (T-25, H4 확정).
     발송 시 INTERNAL 블록 제거, SENT 동결. API 검증 결과는 별도 후속(MORAI-002 트랙). -->

양종범님,

안녕하세요. 한국자동차연구원 정호정입니다. 상세한 환경 정보와 재빌드 파일까지 빠르게 보내주셔서 감사합니다.

권장해 주신 방식(터미널에서 ROS2와 morai_msgs 워크스페이스 소싱 후 런처 직접 실행)으로 재확인한 결과를 공유드립니다. 결론부터 말씀드리면 **이 방식으로 정상 동작을 확인했고, 원인도 특정했습니다.**

- 권장 방식으로 실행 시 SIM이 크래시 없이 기동되고, ROS2 Connect 후 `/ego_vehicle_status` 50Hz 수신과 `/ctrl_cmd` 차량 제어(목표속도 추종·정지)까지 확인했습니다.
- 저희 쪽 crash의 원인은 실행 스크립트가 설정하던 **`RMW_IMPLEMENTATION=rmw_fastrtps_cpp` 환경변수**였습니다. 동일 조건에서 이 변수 하나만 추가하면 기존과 동일한 startup 종료(`std::bad_cast`, rcl의 rmw implementation identifier check 경로)가 재현되고, 제거하면 정상 동작합니다. 소싱 여부나 morai_msgs 버전과는 무관했습니다.
- 참고로 SIM 내장 ros2cs 환경에서 이 변수가 설정되면 초기화가 실패하는 동작은 다른 사용자도 겪을 수 있는 부분으로 보여, 가능하시면 개발팀에 전달해 주시면 좋겠습니다(변수 무시 또는 안내 메시지 등).

rosbridge 건은 ROS2 공식 경로가 아니라는 안내로 이해했고, 저희는 native 경로로 진행하겠습니다.

보내주신 OpenSCENARIO API(Python 3.13) 재빌드는 수령했으며, 환경 구성 후 검증 결과를 별도로 회신드리겠습니다.

그동안 빠른 대응에 감사드립니다.

정호정 드림
