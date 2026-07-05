#!/usr/bin/env bash
# E2 관찰 — ROS2 Native startup 크래시 재검증 (MORAI-001 §3-A + D1 겸용, 적응판)
#   적응: 프로토콜의 "Connect 크래시"는 측정 불가 → 측정 가능한 "SOURCE_ROS2=1 → Start → startup
#         bad_cast 크래시"를 대상으로 한다. GUI는 런처 Start 1회.
#
# 가설: H-a 소싱 실행 시 SIM 이 startup 에서 librmw_fastrtps_cpp std::bad_cast 로 즉시 종료(결정론적).
#       H-b(D1) 종료까지 SIM 은 DDS participant 미생성(RTPS discovery 패킷 0).
# 동일성 기준: 3회 모두 ① Start 후 Simulator 프로세스 소멸 ② Player.log 에 std::bad_cast + librmw_fastrtps_cpp
#              ③ pcap 에 SIM 발신 RTPS 패킷 없음.
#
# 사용: e2_observe.sh <RUN> <start|finish>
#   start  : (sudo 확인 후) tcpdump 시작 + simpid_before 기록. 이후 사용자가 런처 Start 클릭.
#   finish : simpid_after 기록 + tcpdump 종료 + Player.log 수집 + 시그니처 grep + pcap 요약.
# 회차마다 SIM 이 죽으므로 매 회차 런처 재기동 필요(사용자).
set -uo pipefail

RUN="${1:?사용법: $0 <RUN> <start|finish>}"
PHASE="${2:?사용법: $0 <RUN> <start|finish>}"
DATE="${RECHECK_DATE:-20260706}"
BASE="$HOME/avstack/logs/avs007_recheck_${DATE}_run${RUN}"
PIDF="${BASE}_tcpdump.pid"
SIMRE='Simulator|MoraiLauncher'   # comm 매칭(자기 명령 오탐 방지 위해 ps 로 확인)

case "$PHASE" in
  start)
    echo "[E2 run${RUN} start] $(date -Is)"
    ps -eo pid,comm | awk '$2 ~ /^Simulator/{print $1}' | tee "${BASE}_simpid_before.txt"
    echo "-- tcpdump 시작 (RTPS 7400-7500) → ${BASE}_rtps.pcap --"
    sudo nohup tcpdump -i any udp portrange 7400-7500 -nn -w "${BASE}_rtps.pcap" >/dev/null 2>&1 &
    echo $! > "$PIDF"
    sleep 1
    echo "tcpdump PID=$(cat "$PIDF"). 이제 런처에서 지도 로드 → Start (SIM startup 크래시 기대)."
    ;;
  finish)
    echo "[E2 run${RUN} finish] $(date -Is)"
    echo "-- Simulator 프로세스 (소멸 기대) --"
    ps -eo pid,comm | awk '$2 ~ /^Simulator/{print $1" "$2}' | tee "${BASE}_simpid_after.txt"
    [ -s "${BASE}_simpid_after.txt" ] && echo "  [주의] Simulator 살아있음 — 크래시 미발생?" || echo "  → Simulator 소멸 확인(공란)"
    if [ -f "$PIDF" ]; then sudo kill "$(cat "$PIDF")" 2>/dev/null; sleep 1; rm -f "$PIDF"; fi
    echo "-- Player.log 수집 --"
    PL=$(find "$HOME/.config/unity3d/MORAI" -name "Player.log" 2>/dev/null | head -1)
    [ -n "$PL" ] && cp "$PL" "${BASE}_player.log" && echo "  copied: $PL"
    echo "-- 시그니처 grep (bad_cast / librmw_fastrtps / ros2cs) --"
    grep -nE "std::bad_cast|librmw_fastrtps_cpp|ros2cs' metadata|NativeRcl" "${BASE}_player.log" 2>/dev/null | head -8 || echo "  (시그니처 없음)"
    echo "-- pcap: SIM 발신 RTPS 패킷 유무 (D1) --"
    if [ -f "${BASE}_rtps.pcap" ]; then
      N=$(sudo tcpdump -r "${BASE}_rtps.pcap" 2>/dev/null | wc -l)
      echo "  pcap 패킷 수: $N  ($([ "$N" -eq 0 ] && echo 'RTPS 무발신 → D1=FAIL(participant 미생성)' || echo 'RTPS 관측 → D1 재판단 필요'))"
      sudo tcpdump -r "${BASE}_rtps.pcap" 2>/dev/null | head -5
    else echo "  (pcap 없음)"; fi
    echo "-- 증거 파일 --"; ls -1 "${BASE}"_* 2>/dev/null | sed 's#.*/#  #'
    ;;
  *) echo "PHASE must be start|finish" >&2; exit 2;;
esac
