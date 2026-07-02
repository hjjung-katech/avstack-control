#!/usr/bin/env bash
set -euo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
MORAI_DIR="${MORAI_DIR:-$HOME/avstack/morai/launcher/MoraiLauncher_Lin}"
MORAI_BIN="${MORAI_BIN:-MoraiLauncher_Lin.x86_64}"
LOG_DIR="$HOME/avstack/logs"
LOG_FILE="$LOG_DIR/MoraiLauncher_$(date +%F_%H%M%S).log"
mkdir -p "$LOG_DIR"
if [ ! -f "$MORAI_DIR/$MORAI_BIN" ]; then
  echo "[ERROR] $MORAI_DIR/$MORAI_BIN not found" >&2
  exit 1
fi
chmod +x "$MORAI_DIR/$MORAI_BIN"
echo "[INFO] MORAI_DIR=$MORAI_DIR"
echo "[INFO] MORAI_BIN=$MORAI_BIN"
echo "[INFO] LOG_FILE=$LOG_FILE"
cd "$MORAI_DIR"
./"$MORAI_BIN" -logFile "$LOG_FILE"
