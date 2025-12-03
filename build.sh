#!/bin/bash
# MATHIS OS Build Script

set -e

echo "═══════════════════════════════════════════════════"
echo "  MATHIS OS Build System"
echo "═══════════════════════════════════════════════════"

cd boot

# Build boot sector
echo "[1/5] Building boot sector..."
nasm -f bin boot.asm -o boot.bin

# Build stage2
echo "[2/5] Building stage2..."
nasm -f bin stage2.asm -o stage2.bin

# Build kernel (modular)
echo "[3/5] Building 32-bit kernel..."
cd kernel
nasm -f bin core.asm -o ../kernel.bin
cd ..

# Check kernel size
kernel_size=$(wc -c < kernel.bin)
if [ $kernel_size -ne 65536 ]; then
    echo "Error: kernel.bin must be exactly 65536 bytes (64KB), but is $kernel_size bytes"
    exit 1
fi

# Build kernel64
echo "[4/5] Building 64-bit kernel..."
nasm -f bin kernel64/main.asm -o kernel64.bin

echo "[5/5] Creating disk image..."
cat boot.bin stage2.bin kernel.bin kernel64.bin > mathis.img

# Show sizes
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Build Complete!"
echo "═══════════════════════════════════════════════════"
ls -la boot.bin stage2.bin kernel.bin kernel64.bin mathis.img
echo ""
echo "Run: qemu-system-x86_64 -fda boot/mathis.img -boot a -m 128M"
