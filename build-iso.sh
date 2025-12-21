#!/bin/bash
# ============================================================================
# MATHIS OS ISO Builder
# ============================================================================
# Creates a bootable ISO image using GRUB2 and Multiboot.
# Requirements: grub-mkrescue, xorriso
# ============================================================================

set -e

ISO_NAME="mathis-os.iso"
ISO_DIR="/tmp/mathis-iso"

echo "═══════════════════════════════════════════════════"
echo "  MATHIS OS ISO Builder"
echo "═══════════════════════════════════════════════════"

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed."
        echo "Install with: brew install $2"
        exit 1
    fi
}

# On macOS, use i686-elf-grub for BIOS boot support
if command -v i686-elf-grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="i686-elf-grub-mkrescue"
elif command -v grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="grub-mkrescue"
else
    echo "Error: grub-mkrescue not found."
    echo "Install with: brew install i686-elf-grub xorriso"
    exit 1
fi

check_tool xorriso xorriso

# Build kernel first
echo "[1/4] Building kernel..."
./build.sh > /dev/null

# Create ISO directory structure
echo "[2/4] Creating ISO structure..."
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Copy kernel binary
cp boot/kernel.bin "$ISO_DIR/boot/"

# Copy GRUB configuration
cp boot/grub/grub.cfg "$ISO_DIR/boot/grub/"

# Create ISO
echo "[3/4] Creating ISO with $GRUB_MKRESCUE..."
$GRUB_MKRESCUE -o "$ISO_NAME" "$ISO_DIR" 2>/dev/null

# Cleanup
rm -rf "$ISO_DIR"

# Show result
echo "[4/4] Done!"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  ISO Created: $ISO_NAME"
echo "═══════════════════════════════════════════════════"
ls -lh "$ISO_NAME"
echo ""
echo "Test with:"
echo "  qemu-system-x86_64 -cdrom $ISO_NAME -m 128M"
echo ""
echo "Write to USB:"
echo "  sudo dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress"
