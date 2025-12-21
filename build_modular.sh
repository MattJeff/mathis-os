#!/bin/bash
# ============================================================================
# MATHIS OS Modular Build System
# ============================================================================
# Compiles each *_mod.asm module to .o then links together
# ============================================================================

set -e

BUILD_DIR="/tmp/mathis_build"
KERNEL_DIR="boot/kernel"
BOOT_DIR="boot"
NASM="nasm"
NASM_FLAGS="-f elf64"
LD="x86_64-elf-ld"
LD_FLAGS="-T ${KERNEL_DIR}/kernel.ld --no-warn-rwx-segments"
OBJCOPY="x86_64-elf-objcopy"

echo "═══════════════════════════════════════════════════"
echo "  MATHIS OS Modular Build System"
echo "═══════════════════════════════════════════════════"

mkdir -p ${BUILD_DIR}

# ============================================================================
# Phase 1: Boot sector and stage2
# ============================================================================
echo "[1/5] Building boot sector..."
(cd ${BOOT_DIR} && ${NASM} -f bin boot.asm -o ${BUILD_DIR}/boot.bin)

echo "[2/5] Building stage2..."
(cd ${BOOT_DIR} && ${NASM} -f bin stage2.asm -o ${BUILD_DIR}/stage2.bin)

# ============================================================================
# Phase 2: Compile kernel modules
# ============================================================================
echo "[3/5] Compiling kernel modules..."

OBJECTS=""

compile_mod() {
    local src=$1
    local out=$2
    if [ -f "$src" ]; then
        echo "  [OK] $src"
        ${NASM} ${NASM_FLAGS} "$src" -o "$out" 2>&1
        OBJECTS="$OBJECTS $out"
    else
        echo "  [SKIP] $src (not found)"
    fi
}

# Core entry (MUST be first)
compile_mod "${KERNEL_DIR}/core_entry.asm" "${BUILD_DIR}/core_entry.o"

# Core modules
compile_mod "${KERNEL_DIR}/core/tables.asm" "${BUILD_DIR}/tables.o"
compile_mod "${KERNEL_DIR}/core/isr_mod.asm" "${BUILD_DIR}/isr_mod.o"

# Memory management
compile_mod "${KERNEL_DIR}/mm/heap_mod.asm" "${BUILD_DIR}/heap_mod.o"
compile_mod "${KERNEL_DIR}/mm/pmm_mod.asm" "${BUILD_DIR}/pmm_mod.o"

# Input
compile_mod "${KERNEL_DIR}/input/state_mod.asm" "${BUILD_DIR}/state_mod.o"
compile_mod "${KERNEL_DIR}/input/keyboard_mod.asm" "${BUILD_DIR}/keyboard_mod.o"
compile_mod "${KERNEL_DIR}/input/mouse_mod.asm" "${BUILD_DIR}/mouse_mod.o"
compile_mod "${KERNEL_DIR}/input/dispatcher_mod.asm" "${BUILD_DIR}/dispatcher_mod.o"
compile_mod "${KERNEL_DIR}/input/cursor_mod.asm" "${BUILD_DIR}/cursor_mod.o"
compile_mod "${KERNEL_DIR}/input/manager_mod.asm" "${BUILD_DIR}/manager_mod.o"

# Filesystem
compile_mod "${KERNEL_DIR}/fs/ata_mod.asm" "${BUILD_DIR}/ata_mod.o"
compile_mod "${KERNEL_DIR}/fs/vfs_mod.asm" "${BUILD_DIR}/vfs_mod.o"

# Drivers
compile_mod "${KERNEL_DIR}/drivers/rtc_mod.asm" "${BUILD_DIR}/rtc_mod.o"

# UI
compile_mod "${KERNEL_DIR}/ui/video_mod.asm" "${BUILD_DIR}/video_mod.o"
compile_mod "${KERNEL_DIR}/ui/font_mod.asm" "${BUILD_DIR}/font_mod.o"
compile_mod "${KERNEL_DIR}/ui/text_mod.asm" "${BUILD_DIR}/text_mod.o"
compile_mod "${KERNEL_DIR}/ui/draw_mod.asm" "${BUILD_DIR}/draw_mod.o"
compile_mod "${KERNEL_DIR}/ui/colors_mod.asm" "${BUILD_DIR}/colors_mod.o"

# Widgets
compile_mod "${KERNEL_DIR}/widgets/widget_base_mod.asm" "${BUILD_DIR}/widget_base_mod.o"
compile_mod "${KERNEL_DIR}/widgets/button_mod.asm" "${BUILD_DIR}/button_mod.o"
compile_mod "${KERNEL_DIR}/widgets/label_mod.asm" "${BUILD_DIR}/label_mod.o"

# Window Manager
compile_mod "${KERNEL_DIR}/wm/wm_types_mod.asm" "${BUILD_DIR}/wm_types_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_state_mod.asm" "${BUILD_DIR}/wm_state_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_create_mod.asm" "${BUILD_DIR}/wm_create_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_draw_mod.asm" "${BUILD_DIR}/wm_draw_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_input_mod.asm" "${BUILD_DIR}/wm_input_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_controls_mod.asm" "${BUILD_DIR}/wm_controls_mod.o"
compile_mod "${KERNEL_DIR}/wm/wm_mod.asm" "${BUILD_DIR}/wm_mod.o"

# Desktop
compile_mod "${KERNEL_DIR}/desktop/desktop_bg_mod.asm" "${BUILD_DIR}/desktop_bg_mod.o"
compile_mod "${KERNEL_DIR}/desktop/desktop_taskbar_mod.asm" "${BUILD_DIR}/desktop_taskbar_mod.o"
compile_mod "${KERNEL_DIR}/desktop/desktop_icons_mod.asm" "${BUILD_DIR}/desktop_icons_mod.o"
compile_mod "${KERNEL_DIR}/desktop/desktop_mod.asm" "${BUILD_DIR}/desktop_mod.o"

# Apps - Calculator
compile_mod "${KERNEL_DIR}/apps/calc/calc_state_mod.asm" "${BUILD_DIR}/calc_state_mod.o"
compile_mod "${KERNEL_DIR}/apps/calc/calc_draw_mod.asm" "${BUILD_DIR}/calc_draw_mod.o"
compile_mod "${KERNEL_DIR}/apps/calc/calc_mod.asm" "${BUILD_DIR}/calc_mod.o"

# Apps - Clock
compile_mod "${KERNEL_DIR}/apps/clock/clock_mod.asm" "${BUILD_DIR}/clock_mod.o"

# Apps - Editor
compile_mod "${KERNEL_DIR}/apps/editor/editor_mod.asm" "${BUILD_DIR}/editor_mod.o"

# Apps - Files
compile_mod "${KERNEL_DIR}/apps/files/files_dialog_mod.asm" "${BUILD_DIR}/files_dialog_mod.o"
compile_mod "${KERNEL_DIR}/apps/files/files_input_mod.asm" "${BUILD_DIR}/files_input_mod.o"
compile_mod "${KERNEL_DIR}/apps/files/files_mod.asm" "${BUILD_DIR}/files_mod.o"

# Apps - Terminal
compile_mod "${KERNEL_DIR}/apps/terminal/term_mod.asm" "${BUILD_DIR}/term_mod.o"

# Legacy modes removed - using new desktop modules

echo ""
echo "  Total: $(echo $OBJECTS | wc -w) modules"

# ============================================================================
# Phase 3: Link
# ============================================================================
echo "[4/5] Linking kernel..."
${LD} ${LD_FLAGS} ${OBJECTS} -o ${BUILD_DIR}/kernel.elf 2>&1

# Show stats
echo "  Symbols: $(x86_64-elf-nm ${BUILD_DIR}/kernel.elf | wc -l)"

# ============================================================================
# Phase 4: Create binary
# ============================================================================
echo "[5/5] Creating binary..."
${OBJCOPY} -O binary --pad-to=0x90000 ${BUILD_DIR}/kernel.elf ${BUILD_DIR}/kernel.bin

kernel_size=$(wc -c < ${BUILD_DIR}/kernel.bin)
echo "  Kernel size: ${kernel_size} bytes"

# ============================================================================
# Phase 5: Create disk image
# ============================================================================
echo "[6/6] Creating disk image..."

dd if=/dev/zero of=${BUILD_DIR}/mathis.img bs=512 count=20480 2>/dev/null
dd if=${BUILD_DIR}/boot.bin of=${BUILD_DIR}/mathis.img bs=512 seek=0 conv=notrunc 2>/dev/null
dd if=${BUILD_DIR}/stage2.bin of=${BUILD_DIR}/mathis.img bs=512 seek=1 conv=notrunc 2>/dev/null
dd if=${BUILD_DIR}/kernel.bin of=${BUILD_DIR}/mathis.img bs=512 seek=9 conv=notrunc 2>/dev/null

# Copy FAT32 from original if exists
if [ -f "boot/mathis.img" ]; then
    dd if=boot/mathis.img of=${BUILD_DIR}/mathis.img bs=512 skip=2048 seek=2048 count=18432 conv=notrunc 2>/dev/null
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Build Complete!"
echo "═══════════════════════════════════════════════════"
ls -lh ${BUILD_DIR}/kernel.bin ${BUILD_DIR}/mathis.img
echo ""
echo "Run: qemu-system-x86_64 -hda ${BUILD_DIR}/mathis.img -m 128M"
