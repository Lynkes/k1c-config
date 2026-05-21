#!/bin/bash
# Build all K1C MCU firmwares
# Run inside WSL: bash build_k1c.sh
# Requires: gcc-arm-none-eabi python3 make
#
# K1C chip mapping:
#   mcu          GD32F303RET6  @ 120MHz  -> K1_mcu0_120_G32_defconfig  (gd32f303xe, same die as RET6)
#   nozzle_mcu   GD32F303CBT6  @ 120MHz  -> K1_noz0_120_G30_defconfig  (gd32f303xb, CB=XB package)
#   leveling_mcu GD32E230F8P6  @  72MHz  -> K1_bed0_110_G21_defconfig  (gd32e230x8, F8=X8 package)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUT_DIR="$SCRIPT_DIR/fw/K1"
mkdir -p "$OUT_DIR"

# List of configs and corresponding output binary names
declare -A CONFIGS
CONFIGS["K1_mcu0_120_G32"]="mcu0_120_G32-mcu0_004_000.bin"
CONFIGS["K1_mcu0_110_G32"]="mcu0_110_G32-mcu0_004_000.bin"
CONFIGS["K1_noz0_120_G30"]="noz0_120_G30-noz0_003_000.bin"
CONFIGS["K1_noz0_110_G30"]="noz0_110_G30-noz0_002_000.bin"
CONFIGS["K1_noz0_110_S06"]="noz0_110_S06-noz0_000_000.bin"
CONFIGS["K1_bed0_110_G21"]="bed0_110_G21-bed0_004_000.bin"
CONFIGS["K1_bed0_100_G21"]="bed0_100_G21-bed0_004_000.bin"

# K1C targets (the ones actually shipped with K1C)
K1C_TARGETS=(
    "K1_mcu0_120_G32"
    "K1_noz0_120_G30"
    "K1_bed0_110_G21"
)

echo "========================================"
echo " K1C Firmware Build"
echo " Output: $OUT_DIR"
echo "========================================"

# Verify toolchain
if ! command -v arm-none-eabi-gcc &>/dev/null; then
    echo "ERROR: arm-none-eabi-gcc not found."
    echo "Install with: sudo apt install gcc-arm-none-eabi"
    exit 1
fi

echo "Toolchain: $(arm-none-eabi-gcc --version | head -1)"
echo ""

BUILD_ERRORS=0

for CFG in "${K1C_TARGETS[@]}"; do
    BIN_NAME="${CONFIGS[$CFG]}"
    echo "----------------------------------------"
    echo "Building: $CFG  ->  $BIN_NAME"
    echo "----------------------------------------"

    make distclean
    make "${CFG}_defconfig"
    make -j"$(nproc)"

    # klipper.bin is generated from klipper.elf by the board Makefile
    if [ -f "out/klipper.bin" ]; then
        cp "out/klipper.bin" "$OUT_DIR/$BIN_NAME"
        SIZE=$(stat -c%s "$OUT_DIR/$BIN_NAME")
        echo "  OK: $BIN_NAME (${SIZE} bytes)"
    elif [ -f "out/klipper.elf" ]; then
        # Fallback: extract binary manually
        arm-none-eabi-objcopy -O binary out/klipper.elf "$OUT_DIR/$BIN_NAME"
        SIZE=$(stat -c%s "$OUT_DIR/$BIN_NAME")
        echo "  OK (objcopy): $BIN_NAME (${SIZE} bytes)"
    else
        echo "  FAILED: no output binary found for $CFG"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
    fi

    echo ""
done

echo "========================================"
if [ "$BUILD_ERRORS" -eq 0 ]; then
    echo " All builds successful."
else
    echo " $BUILD_ERRORS build(s) FAILED."
fi
echo ""
echo " Binaries in: $OUT_DIR"
ls -lh "$OUT_DIR"
echo "========================================"

exit "$BUILD_ERRORS"
