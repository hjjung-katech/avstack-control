#!/usr/bin/env bash
# Stage 05 [AVS-007 #2] — SIM ros2cs 빌드시점(2023-03-31)의 Fast-DDS 계열 deb 를
# ROS snapshot 에서 받아 별도 prefix 로 추출. 시스템 /opt/ros/humble 은 건드리지 않는다.
# 네트워크 필요 → 사용자가 직접 실행. dpkg-deb 만 사용(설치 아님, sudo 불필요).
#
# 배경: host Humble fastrtps=2.6.11(2026)로는 SIM 번들 typesupport(2023)와 std::bad_cast.
#       동일 날짜 fastrtps 를 SIM 에만 LD_LIBRARY_PATH 로 앞세워 H1(버전 ABI) 가설을 검증.
set -euo pipefail

SNAPSHOT_DATE="${SNAPSHOT_DATE:-2023-03-31}"          # SIM metadata_ros2cs.xml 빌드일과 일치
PREFIX="${FASTDDS_PREFIX:-$HOME/avstack/ros2-fastdds-snap}"
BASE="http://snapshots.ros.org/humble/${SNAPSHOT_DATE}/ubuntu"
ARCH="binary-amd64"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# SIM 번들 typesupport_fastrtps 가 링크하는 Fast-DDS 계열 런타임 패키지들
PKGS=(
  ros-humble-fastrtps
  ros-humble-fastcdr
  ros-humble-foonathan-memory-vendor
  ros-humble-rmw-fastrtps-cpp
  ros-humble-rmw-fastrtps-shared-cpp
  ros-humble-rosidl-typesupport-fastrtps-c
  ros-humble-rosidl-typesupport-fastrtps-cpp
)

echo "[info] snapshot=$SNAPSHOT_DATE  prefix=$PREFIX"
echo "[info] Packages 인덱스 다운로드..."
IDX="$WORK/Packages"
if ! curl -fsSL "$BASE/dists/jammy/main/${ARCH}/Packages.gz" | gunzip > "$IDX"; then
  echo "[ERROR] $SNAPSHOT_DATE 스냅샷 인덱스 접근 실패. 날짜를 바꿔 재시도: SNAPSHOT_DATE=YYYY-MM-DD" >&2
  echo "        (스냅샷 목록: http://snapshots.ros.org/humble/ )" >&2
  exit 3
fi

mkdir -p "$PREFIX"
resolve_filename() {  # $1=pkg → Packages 에서 Filename 추출(해당 스냅샷의 그 시점 버전)
  awk -v p="$1" '
    $1=="Package:"{cur=$2}
    cur==p && $1=="Filename:"{print $2; exit}' "$IDX"
}

for pkg in "${PKGS[@]}"; do
  fn="$(resolve_filename "$pkg")"
  if [ -z "$fn" ]; then echo "[WARN] $pkg 인덱스에 없음(스킵)"; continue; fi
  ver="$(awk -v p="$pkg" '$1=="Package:"{c=$2} c==p && $1=="Version:"{print $2; exit}' "$IDX")"
  echo "[get] $pkg $ver"
  curl -fsSL "$BASE/$fn" -o "$WORK/$(basename "$fn")"
  dpkg-deb -x "$WORK/$(basename "$fn")" "$PREFIX"
done

echo; echo "[done] 추출 위치: $PREFIX"
LIBDIR="$PREFIX/opt/ros/humble/lib"
echo "[libs] 핵심 라이브러리 버전:"
ls "$LIBDIR"/libfastrtps.so* "$LIBDIR"/libfastcdr.so* "$LIBDIR"/librmw_fastrtps_cpp.so 2>/dev/null | sed 's#.*/##' || true
echo
echo "다음: SIM 을 이 prefix 로 실행 —"
echo "  SOURCE_ROS2=1 FASTDDS_PREFIX=$PREFIX bash scripts/run_morai_launcher_nvidia.sh"
