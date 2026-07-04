#!/usr/bin/env bash
# AVS-007 계층 진단 오케스트레이터 — D1→D2→D3→D4 순차, 하위 계층 FAIL 시 즉시 종료.
# [avs-007_layer_diagnosis.md §4 중지 조건 / §5 판정 매트릭스]
# 전체 출력을 ~/avstack/runs/avs007_diag_<ts>.log 로 tee.
#
# 사용: run_all_diag.sh <SIM_UI_Domain값> [토픽명=/Ego_topic]
#   (사전: preflight.sh 통과, SIM 켜짐+지도 로드, rosbridge 전부 종료)
# 주의: D1 은 sudo tcpdump 확인 프롬프트가 있다. D5(제어 역방향)는 Ego 를 실제로 움직이므로
#       자동 실행하지 않는다 — 필요 시 별도로 scripts/stage05_ros2_native/send_ctrl_cmd.sh.
set -uo pipefail

SIM_DOMAIN="${1:?사용법: $0 <SIM_UI_Domain값> [토픽명]}"
TOPIC="${2:-/Ego_topic}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d_%H%M%S)
LOG="$HOME/avstack/runs/avs007_diag_${TS}.log"

matrix() { echo; echo "###### 판정 매트릭스 행: $1"; echo "###### 후속: $2"; }

{
  echo "===== AVS-007 계층 진단 시작 ($TS) — DOMAIN(UI)=$SIM_DOMAIN TOPIC=$TOPIC ====="

  echo; echo "########## D1: DDS participant ##########"
  if ! bash "$HERE/d1_dds_participant.sh"; then
    rc=$?
    if [ "$rc" -eq 3 ]; then
      echo "[중단] D1 tcpdump 생략됨 — 판정 보류. tcpdump 허용 후 재실행."
    else
      matrix "D1 FAIL → 벤더(ros2cs 미동작)" \
             "MORAI 문의에 D1 실측 첨부(/tmp/d1_*.txt), issues.tsv AVS-007 AMEND, Stage05 BLOCKED 유지"
    fi
    exit 1
  fi

  echo; echo "########## D2: Domain × RMW ##########"
  if bash "$HERE/d2_domain_rmw.sh" "$SIM_DOMAIN"; then
    echo "[안내] D2 에서 토픽이 보인 조합의 env 로 아래를 이어가라:"
    echo "       ROS_DOMAIN_ID=<값> RMW_IMPLEMENTATION=<값> bash $HERE/d3_qos_probe.sh $TOPIC"
    D2OK=1
  else
    D2OK=0
  fi

  if [ "$D2OK" -eq 0 ]; then
    echo; echo "########## D4 (D2 전멸 시 1회 확인 후 종료) ##########"
    if bash "$HERE/d4_lazy_publisher.sh" "$TOPIC"; then
      matrix "PASS/미해결/—/H4 채택 → lazy publisher 특성" \
             "문서화 + rosbag 상시 구독 전제 확인, Stage05 조건부 PASS"
    else
      matrix "D1 PASS, D2 전조합 미출현, D4 기각 → 벤더(publisher 무발행)" \
             "MORAI 문의 보강(participant 있음 + 구독자 부착에도 무발행), issues.tsv AMEND"
    fi
    exit 1
  fi

  echo; echo "########## D3: QoS 착시 ##########"
  if bash "$HERE/d3_qos_probe.sh" "$TOPIC"; then
    matrix "D1 PASS, D2 해결, D3 해결 → 진단 도구(착시) 또는 환경 설정" \
           "Stage05 판정 정정, verify_topics.sh QoS 반영, env 변경은 ADR, 오진 회고 기록"
    exit 0
  fi

  echo; echo "########## D4: lazy publisher ##########"
  if bash "$HERE/d4_lazy_publisher.sh" "$TOPIC"; then
    matrix "PASS/PASS/FAIL/H4 채택 → lazy publisher 특성" \
           "문서화 + rosbag 상시 구독 전제, Stage05 조건부 PASS"
    exit 0
  else
    matrix "PASS/PASS/FAIL/H4 기각 → 벤더(publisher 무발행)" \
           "MORAI 문의 보강, issues.tsv AVS-007 AMEND"
    exit 1
  fi
} 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
echo "EVIDENCE=$LOG"
echo "민감정보 점검:"; grep -i -E "token|license|auth|password|key|secret" "$LOG" >/dev/null && echo "  [!] 로그에 민감 후보 있음 — 공유 전 확인" || echo "  (없음)"
exit "$rc"
