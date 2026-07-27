#!/usr/bin/env bash
# inventory_avstack.sh — READ-ONLY inventory of a host's ~/avstack workspace [WS].
# NW-01 자산 인벤토리용. 어떤 파일도 수정/삭제하지 않는다.
# 민감파일(라이선스/토큰/계정)은 "이름·크기만" 나열하고 내용은 절대 출력하지 않는다.
# 사용: bash inventory_avstack.sh   (출력은 stdout + ~/avstack_inventory_<host>_<ts>.txt)
set -u

WS="${AVSTACK_WS:-$HOME/avstack}"
HOST="$(hostname)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$HOME/avstack_inventory_${HOST}_${TS}.txt"

# 민감 후보 패턴 (내용 미출력, 존재/크기만)
SECRET_RE='license|licence|token|auth|passwd|password|secret|\.key$|\.pem$|account|credential|\.pye$'

{
  echo "# AVStack ~/avstack inventory"
  echo "host=$HOST  user=$USER  ws=$WS  ts=$TS"
  echo "kernel=$(uname -r)  os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?}")"
  echo

  if [ ! -d "$WS" ]; then
    echo "!! $WS 없음 — 이 호스트에 워크스페이스가 없습니다."
    exit 0
  fi

  echo "== top-level (depth 1) sizes =="
  du -h --max-depth=1 "$WS" 2>/dev/null | sort -h
  echo "total: $(du -sh "$WS" 2>/dev/null | cut -f1)"
  echo

  echo "== directory tree (depth 2, dirs only) =="
  find "$WS" -maxdepth 2 -type d 2>/dev/null | sort
  echo

  echo "== key files (VERSIONS.lock / *.yml env / launchers) =="
  find "$WS" -maxdepth 3 \( -name 'VERSIONS.lock' -o -name 'environment*.yml' -o -name '*.x86_64' -o -name 'MORAISim.sh' -o -name 'MoraiLauncher*' \) \
    -printf '%12s  %TY-%Tm-%Td  %p\n' 2>/dev/null | sort -k3
  echo

  echo "== checksums of key binaries/launchers (integrity) =="
  find "$WS" -maxdepth 4 \( -name '*.x86_64' -o -name 'MORAISim.sh' -o -name 'MoraiLauncher*' -o -name 'VERSIONS.lock' \) -type f 2>/dev/null \
    | while read -r f; do sha256sum "$f" 2>/dev/null; done
  echo

  echo "== scenarios (*.xosc / *.osc count + list) =="
  find "$WS" -maxdepth 4 \( -name '*.xosc' -o -name '*.osc' \) -type f 2>/dev/null | sort | sed "s|$WS/||"
  echo

  echo "== SECRET-suspect files (NAME + SIZE ONLY, contents NOT read) =="
  find "$WS" -maxdepth 5 -type f 2>/dev/null | grep -iE "$SECRET_RE" \
    | while read -r f; do printf '%12s  %s\n' "$(stat -c%s "$f" 2>/dev/null)" "${f#$WS/}"; done
  echo "  (위 파일들은 이관 SECRET 클래스 — checksum/내용 제외, 계정/라이선스는 재발급/수동 처리)"
  echo

  echo "== conda envs (name + path) =="
  (conda env list 2>/dev/null || ~/miniconda3/bin/conda env list 2>/dev/null || echo "conda not found")
  echo

  echo "== git-tracked? (should be non-git per ADR-011) =="
  git -C "$WS" rev-parse --is-inside-work-tree 2>/dev/null && echo "WARN: $WS is a git repo" || echo "ok: not a git repo"
  echo
  echo "# END inventory ($OUT)"
} 2>&1 | tee "$OUT"

echo
echo ">>> 공유용 파일: $OUT"
