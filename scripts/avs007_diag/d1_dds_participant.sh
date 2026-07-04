#!/usr/bin/env bash
# D1 — DDS Participant 존재 검증 (최하위 계층)  [avs-007_layer_diagnosis.md §4.D1]
#
# 가설 H1: SIM 내장 ros2cs 가 초기화 실패 → DDS participant 자체가 안 생긴다 (벤더 귀속).
# 변경점: 없음(순수 관찰).
# 판정:
#   - SIM PID 가 UDP 7400~7500 포트 보유 + SIM 발신 RTPS 패킷 관측 → D1 PASS → d2 진행
#   - 포트 없음 / SIM 발신 패킷 없음                              → D1 FAIL → 벤더 확정, 진단 종료
#   - daemon 등 타 프로세스 패킷만 → ros2 daemon stop 후 1회 재시도, 그래도 모호 → FAIL 처리
# 중지 조건: tcpdump 60초 최대 2회.
set -uo pipefail

echo "== D1: DDS participant 검증 ($(date +%F' '%T)) =="

# 1. SIM 프로세스 PID (정확 매칭: comm 기준 — pgrep -f 는 자기 명령 오탐 이력 있음)
SIM_PIDS=$(ps -eo pid,comm | awk '$2 ~ /^(Simulator|MoraiLauncher)/{print $1}' | paste -sd'|')
echo "SIM_PIDS=${SIM_PIDS:-없음}"
if [ -z "${SIM_PIDS:-}" ]; then
  echo "[FAIL] SIM 프로세스 없음 — SIM 을 켜고 재실행"; exit 2
fi

# 2. SIM 이 연 UDP 포트 (RTPS discovery 대역 7400~7500)
echo; echo "-- SIM 프로세스의 UDP 포트 --"
ss -ulpn 2>/dev/null | grep -E "pid=(${SIM_PIDS})," | tee /tmp/d1_ports.txt || true
RTPS_PORTS=$(grep -cE ":74[0-9][0-9] " /tmp/d1_ports.txt 2>/dev/null || echo 0)
echo "RTPS 대역(74xx) 포트 수: $RTPS_PORTS"

# 3. RTPS 패킷 관찰 (sudo 필요 — 확인 후 진행)
echo
read -r -p "sudo tcpdump 로 RTPS 패킷을 60초 관찰한다. 진행? [y/N] " ans
if [ "${ans,,}" != "y" ]; then
  echo "[SKIP] tcpdump 생략 — 포트 관측만으로는 판정 불충분. 판정 보류."; exit 3
fi
echo "-- tcpdump (60초 또는 50패킷) --"
sudo timeout 60 tcpdump -i any -c 50 udp portrange 7400-7500 -nn 2>&1 | tee /tmp/d1_rtps.txt || true
PKTS=$(grep -cE "^[0-9]+:" /tmp/d1_rtps.txt 2>/dev/null || grep -c "UDP" /tmp/d1_rtps.txt 2>/dev/null || echo 0)

echo
echo "== D1 판정 가이드 =="
echo "  포트(74xx): $RTPS_PORTS 개 | RTPS 패킷 라인: $PKTS"
if [ "$RTPS_PORTS" -gt 0 ] && [ "$PKTS" -gt 0 ]; then
  echo "  → D1 PASS 후보: participant 존재. (패킷 발신 PID 가 SIM 인지 /tmp/d1_ports.txt 와 대조)"
  echo "  → 다음: d2_domain_rmw.sh <SIM_UI_Domain값>"
  exit 0
else
  echo "  → D1 FAIL 후보: SIM 의 RTPS 활동 없음 → 벤더(ros2cs 미동작) 확정."
  echo "     모호하면(타 프로세스 패킷만): ros2 daemon stop 후 이 스크립트 1회만 재시도."
  echo "  → 진단 종료: MORAI 문의에 /tmp/d1_ports.txt, /tmp/d1_rtps.txt 첨부."
  exit 1
fi
