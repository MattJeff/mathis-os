#!/bin/bash
# MATHIS OS Build Script - Hard Disk Edition

set -e

echo "═══════════════════════════════════════════════════"
echo "  MATHIS OS Build System (HDD Edition)"
echo "═══════════════════════════════════════════════════"

cd boot

# Build boot sector
echo "[1/5] Building boot sector..."
nasm -f bin boot.asm -o boot.bin

# Build stage2
echo "[2/5] Building stage2..."
nasm -f bin stage2.asm -o stage2.bin

# Build kernel (modular)
echo "[3/5] Building 256KB kernel..."
cd kernel
nasm -f bin core.asm -o ../kernel.bin
cd ..

# Check kernel size (256KB)
kernel_size=$(wc -c < kernel.bin)
if [ $kernel_size -ne 262144 ]; then
    echo "Error: kernel.bin must be exactly 262144 bytes (256KB), but is $kernel_size bytes"
    exit 1
fi

# Build kernel64 (not used anymore, but keep for compatibility)
echo "[4/5] Building 64-bit kernel..."
nasm -f bin kernel64/main.asm -o kernel64.bin

echo "[5/5] Creating 10MB hard disk image..."

# Create 10MB disk image
dd if=/dev/zero of=mathis.img bs=512 count=20480 2>/dev/null

# Write boot sector at LBA 0
dd if=boot.bin of=mathis.img bs=512 seek=0 conv=notrunc 2>/dev/null

# Write stage2 at LBA 1-8
dd if=stage2.bin of=mathis.img bs=512 seek=1 conv=notrunc 2>/dev/null

# Write kernel at LBA 9+ (512 sectors = 256KB)
dd if=kernel.bin of=mathis.img bs=512 seek=9 conv=notrunc 2>/dev/null

# Show sizes
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Build Complete!"
echo "═══════════════════════════════════════════════════"
ls -la boot.bin stage2.bin kernel.bin mathis.img
echo ""
echo "Disk layout:"
echo "  LBA 0:     Boot sector (512B)"
echo "  LBA 1-8:   Stage2 (4KB)"
echo "  LBA 9-520: Kernel (256KB)"
echo "  LBA 521+:  Filesystem (available)"
echo ""
echo "Run: qemu-system-x86_64 -hda boot/mathis.img -m 128M"
