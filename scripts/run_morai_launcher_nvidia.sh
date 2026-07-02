#!/usr/bin/env bash
# Official launch path per MORAI SIM: Drive manual (Installation and Setup):
#   https://morai-sim--drive-user-manual--en-22-r2.scrollhelp.site/msdume2/installation-and-setup
#   $ chmod +x MORAISim.sh && chmod +x MoraiLauncher_Lin.x86_64 && ./MORAISim.sh
# The manual omits GPU offload; we wrap MORAISim.sh with NVIDIA PRIME offload.
# NOTE: on this host MORAISim.sh triggers NO sudo — its keylok install line is
# commented out and the Kvaser CAN symlink is skipped (no /usr/lib/libcanlib.so).
# If a future MORAI build re-enables those, review before running (see runbook 10.2).
set -euo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __VK_LAYER_NV_optimus=NVIDIA_only    # SIM renders via Vulkan (log-confirmed)
export __GLX_VENDOR_LIBRARY_NAME=nvidia      # harmless; only used by any GLX fallback

# Remote (SSH -> NoMachine): target the X session shown over NoMachine.
# Set RUN_REMOTE=1 to enable, or export DISPLAY/XAUTHORITY yourself.
if [ "${RUN_REMOTE:-0}" = "1" ]; then
  export DISPLAY="${DISPLAY:-:1}"
  export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
fi

# Real layout: launcher/MoraiLauncher_Lin is a symlink to the active _a/_b slot.
MORAI_DIR="${MORAI_DIR:-$HOME/avstack/morai/launcher/MoraiLauncher_Lin}"
LAUNCH_SH="${LAUNCH_SH:-MORAISim.sh}"
LOG_DIR="$HOME/avstack/logs"
LOG_FILE="$LOG_DIR/MoraiLauncher_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"

if [ ! -f "$MORAI_DIR/$LAUNCH_SH" ]; then
  echo "[ERROR] $MORAI_DIR/$LAUNCH_SH not found" >&2
  exit 1
fi
chmod +x "$MORAI_DIR/$LAUNCH_SH" "$MORAI_DIR/MoraiLauncher_Lin.x86_64" 2>/dev/null || true
echo "[INFO] MORAI_DIR=$MORAI_DIR"
echo "[INFO] LAUNCH=$LAUNCH_SH  DISPLAY=${DISPLAY:-(inherited)}"
echo "[INFO] LOG_FILE=$LOG_FILE"
cd "$MORAI_DIR"
./"$LAUNCH_SH" 2>&1 | tee "$LOG_FILE"
