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

# Build kernel (with linker) - ELF64 then objcopy to binary
echo "[3/5] Building 512KB kernel..."
cd kernel
nasm -f elf64 -w-label-redef-late core.asm -o core.o
x86_64-elf-ld -T kernel.ld -o kernel.elf core.o
x86_64-elf-objcopy -O binary --pad-to=0x90000 kernel.elf ../kernel.bin
rm -f core.o kernel.elf
cd ..

# Check kernel size (512KB)
kernel_size=$(wc -c < kernel.bin)
if [ $kernel_size -ne 524288 ]; then
    echo "Error: kernel.bin must be exactly 524288 bytes (512KB), but is $kernel_size bytes"
    exit 1
fi

# Build kernel64 (not used anymore, but keep for compatibility)
echo "[4/5] Building 64-bit kernel..."
nasm -f bin kernel64/main.asm -o kernel64.bin

echo "[5/5] Creating 10MB hard disk image with FAT32..."

# Create 10MB disk image
dd if=/dev/zero of=mathis.img bs=512 count=20480 2>/dev/null

# Write boot sector at LBA 0
dd if=boot.bin of=mathis.img bs=512 seek=0 conv=notrunc 2>/dev/null

# Write stage2 at LBA 1-8
dd if=stage2.bin of=mathis.img bs=512 seek=1 conv=notrunc 2>/dev/null

# Write kernel at LBA 9+ (1024 sectors = 512KB)
dd if=kernel.bin of=mathis.img bs=512 seek=9 conv=notrunc 2>/dev/null

# Create partition table entry at offset 446 (first partition)
# Partition starts at LBA 2048, size = 18432 sectors (~9MB)
# Type = 0x0C (FAT32 LBA)
python3 -c "
import struct
# Partition entry: boot, CHS start, type, CHS end, LBA start, LBA size
# We use LBA addressing, CHS values are placeholders
entry = bytes([
    0x00,           # Not bootable
    0x00, 0x21, 0x00,  # CHS start (placeholder)
    0x0C,           # Type: FAT32 LBA
    0x00, 0x00, 0x00,  # CHS end (placeholder)
]) + struct.pack('<I', 2048) + struct.pack('<I', 18432)  # LBA start, size

# Write at offset 446
with open('mathis.img', 'r+b') as f:
    f.seek(446)
    f.write(entry)
    # Pad remaining 3 partition entries with zeros (already zero)
"

# Create FAT32 boot sector at LBA 2048
python3 -c "
import struct

# FAT32 BPB (BIOS Parameter Block)
bpb = bytearray(512)

# Jump instruction
bpb[0:3] = bytes([0xEB, 0x58, 0x90])

# OEM name
bpb[3:11] = b'MATHIS  '

# Bytes per sector
struct.pack_into('<H', bpb, 11, 512)

# Sectors per cluster (8 = 4KB clusters for small disk)
bpb[13] = 8

# Reserved sectors
struct.pack_into('<H', bpb, 14, 32)

# Number of FATs
bpb[16] = 2

# Root entry count (0 for FAT32)
struct.pack_into('<H', bpb, 17, 0)

# Total sectors 16-bit (0 for FAT32)
struct.pack_into('<H', bpb, 19, 0)

# Media type
bpb[21] = 0xF8

# FAT size 16 (0 for FAT32)
struct.pack_into('<H', bpb, 22, 0)

# Sectors per track
struct.pack_into('<H', bpb, 24, 63)

# Number of heads
struct.pack_into('<H', bpb, 26, 255)

# Hidden sectors (partition start)
struct.pack_into('<I', bpb, 28, 2048)

# Total sectors 32-bit
struct.pack_into('<I', bpb, 32, 18432)

# FAT32 specific fields
# Sectors per FAT
struct.pack_into('<I', bpb, 36, 143)  # ~18432 / 128 sectors need FAT entries

# Extended flags
struct.pack_into('<H', bpb, 40, 0)

# Version
struct.pack_into('<H', bpb, 42, 0)

# Root cluster
struct.pack_into('<I', bpb, 44, 2)

# FSInfo sector
struct.pack_into('<H', bpb, 48, 1)

# Backup boot sector
struct.pack_into('<H', bpb, 50, 6)

# Reserved (12 bytes at offset 52)

# Drive number
bpb[64] = 0x80

# Reserved
bpb[65] = 0

# Extended boot signature
bpb[66] = 0x29

# Volume serial number
struct.pack_into('<I', bpb, 67, 0x12345678)

# Volume label
bpb[71:82] = b'MATHIS_OS  '

# File system type
bpb[82:90] = b'FAT32   '

# Boot signature
bpb[510] = 0x55
bpb[511] = 0xAA

with open('mathis.img', 'r+b') as f:
    f.seek(2048 * 512)  # LBA 2048
    f.write(bpb)
"

# Create FAT tables at LBA 2048+32 (after reserved sectors)
# First FAT entry = media type, second = end of chain for root
python3 -c "
import struct

fat = bytearray(512)

# Entry 0: Media type (0x0FFFFFF8)
struct.pack_into('<I', fat, 0, 0x0FFFFFF8)

# Entry 1: End of chain marker
struct.pack_into('<I', fat, 4, 0x0FFFFFFF)

# Entry 2: Root directory cluster (end of chain)
struct.pack_into('<I', fat, 8, 0x0FFFFFFF)

with open('mathis.img', 'r+b') as f:
    # First FAT at LBA 2048 + 32 = 2080
    f.seek((2048 + 32) * 512)
    f.write(fat)
    # Second FAT at LBA 2048 + 32 + 143 = 2223
    f.seek((2048 + 32 + 143) * 512)
    f.write(fat)
"

# Create root directory with test files at first data cluster (LBA 2048 + 32 + 286)
python3 -c "
import struct

# Create directory entries
entries = bytearray(512)

# Entry 1: Volume label
entries[0:11] = b'MATHIS_OS  '
entries[11] = 0x08  # Volume label attribute

# Entry 2: A folder named 'PROJECTS'
entries[32:40] = b'PROJECTS'
entries[40:43] = b'   '  # Extension
entries[32+11] = 0x10  # Directory attribute
struct.pack_into('<H', entries, 32+20, 0)  # High cluster
struct.pack_into('<H', entries, 32+26, 3)  # Low cluster (cluster 3)
struct.pack_into('<I', entries, 32+28, 0)  # Size 0 for dir

# Entry 3: A file named 'README.TXT'
entries[64:72] = b'README  '
entries[72:75] = b'TXT'
entries[64+11] = 0x20  # Archive attribute
struct.pack_into('<H', entries, 64+20, 0)  # High cluster
struct.pack_into('<H', entries, 64+26, 4)  # Low cluster (cluster 4)
struct.pack_into('<I', entries, 64+28, 45)  # Size

# Entry 4: A file named 'HELLO.ASM'
entries[96:104] = b'HELLO   '
entries[104:107] = b'ASM'
entries[96+11] = 0x20  # Archive attribute
struct.pack_into('<H', entries, 96+20, 0)  # High cluster
struct.pack_into('<H', entries, 96+26, 5)  # Low cluster (cluster 5)
struct.pack_into('<I', entries, 96+28, 128)  # Size

# Entry 5: DESKTOP folder
entries[128:136] = b'DESKTOP '
entries[136:139] = b'   '
entries[128+11] = 0x10  # Directory attribute
struct.pack_into('<H', entries, 128+20, 0)  # High cluster
struct.pack_into('<H', entries, 128+26, 6)  # Low cluster (cluster 6)
struct.pack_into('<I', entries, 128+28, 0)  # Size 0 for dir

# Entry 6: DOWNLOAD folder (8 chars max for FAT32)
entries[160:168] = b'DOWNLOAD'
entries[168:171] = b'   '
entries[160+11] = 0x10  # Directory attribute
struct.pack_into('<H', entries, 160+20, 0)  # High cluster
struct.pack_into('<H', entries, 160+26, 7)  # Low cluster (cluster 7)
struct.pack_into('<I', entries, 160+28, 0)  # Size 0 for dir

# Entry 7: DOCS folder (8 chars max for FAT32)
entries[192:200] = b'DOCS    '
entries[200:203] = b'   '
entries[192+11] = 0x10  # Directory attribute
struct.pack_into('<H', entries, 192+20, 0)  # High cluster
struct.pack_into('<H', entries, 192+26, 8)  # Low cluster (cluster 8)
struct.pack_into('<I', entries, 192+28, 0)  # Size 0 for dir

with open('mathis.img', 'r+b') as f:
    # Root directory at cluster 2 = LBA 2048 + 32 + 286 = 2366
    # Actually: data_start = reserved + FAT1 + FAT2 = 32 + 143 + 143 = 318
    # Cluster 2 = LBA 2048 + 318
    f.seek((2048 + 318) * 512)
    f.write(entries)
"

# Allocate clusters 3, 4, 5 in FAT (for PROJECTS dir, README.TXT, HELLO.ASM)
python3 -c "
import struct

# Read FAT
with open('mathis.img', 'r+b') as f:
    f.seek((2048 + 32) * 512)
    fat = bytearray(f.read(512))

    # Cluster 3: PROJECTS dir (end of chain)
    struct.pack_into('<I', fat, 12, 0x0FFFFFFF)

    # Cluster 4: README.TXT (end of chain)
    struct.pack_into('<I', fat, 16, 0x0FFFFFFF)

    # Cluster 5: HELLO.ASM (end of chain)
    struct.pack_into('<I', fat, 20, 0x0FFFFFFF)

    # Cluster 6: DESKTOP dir (end of chain)
    struct.pack_into('<I', fat, 24, 0x0FFFFFFF)

    # Cluster 7: DOWNLOADS dir (end of chain)
    struct.pack_into('<I', fat, 28, 0x0FFFFFFF)

    # Cluster 8: DOCUMENTS dir (end of chain)
    struct.pack_into('<I', fat, 32, 0x0FFFFFFF)

    # Write back FAT1
    f.seek((2048 + 32) * 512)
    f.write(fat)

    # Write back FAT2
    f.seek((2048 + 32 + 143) * 512)
    f.write(fat)
"

# Write README.TXT content
python3 -c "
content = b'Welcome to MATHIS OS!\\n\\nThis is a test file.\\n'
content = content.ljust(512, b'\\x00')

with open('mathis.img', 'r+b') as f:
    # Cluster 4 = LBA 2048 + 318 + (4-2)*8 = 2048 + 318 + 16 = 2382
    f.seek((2048 + 318 + 16) * 512)
    f.write(content)
"

# Write HELLO.ASM content
python3 -c "
content = b'''; Hello World in x86 Assembly
section .text
global _start
_start:
    mov rax, 1      ; write
    mov rdi, 1      ; stdout
    mov rsi, msg    ; message
    mov rdx, 13     ; length
    syscall
    mov rax, 60     ; exit
    xor rdi, rdi
    syscall
section .data
msg: db \"Hello World!\", 10
'''
content = content.ljust(512, b'\\x00')

with open('mathis.img', 'r+b') as f:
    # Cluster 5 = LBA 2048 + 318 + (5-2)*8 = 2048 + 318 + 24 = 2390
    f.seek((2048 + 318 + 24) * 512)
    f.write(content)
"

# Initialize DESKTOP, DOWNLOADS, DOCUMENTS directories with . and ..
python3 -c "
import struct

def create_dir_entries(cluster_num, parent_cluster):
    '''Create . and .. entries for a directory'''
    entries = bytearray(4096)  # 8 sectors per cluster

    # . entry (self)
    entries[0:8] = b'.       '
    entries[8:11] = b'   '
    entries[11] = 0x10  # Directory
    struct.pack_into('<H', entries, 20, 0)  # High cluster
    struct.pack_into('<H', entries, 26, cluster_num)  # Low cluster

    # .. entry (parent)
    entries[32:40] = b'..      '
    entries[40:43] = b'   '
    entries[32+11] = 0x10  # Directory
    struct.pack_into('<H', entries, 32+20, 0)  # High cluster
    struct.pack_into('<H', entries, 32+26, parent_cluster)  # Low cluster

    return entries

with open('mathis.img', 'r+b') as f:
    # Root is cluster 2
    # DESKTOP = cluster 6 = LBA 2048 + 318 + (6-2)*8 = 2048 + 318 + 32 = 2398
    f.seek((2048 + 318 + 32) * 512)
    f.write(create_dir_entries(6, 2))

    # DOWNLOADS = cluster 7 = LBA 2048 + 318 + (7-2)*8 = 2048 + 318 + 40 = 2406
    f.seek((2048 + 318 + 40) * 512)
    f.write(create_dir_entries(7, 2))

    # DOCUMENTS = cluster 8 = LBA 2048 + 318 + (8-2)*8 = 2048 + 318 + 48 = 2414
    f.seek((2048 + 318 + 48) * 512)
    f.write(create_dir_entries(8, 2))
"

echo "  FAT32 filesystem created at LBA 2048"

# Show sizes
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Build Complete!"
echo "═══════════════════════════════════════════════════"
ls -la boot.bin stage2.bin kernel.bin mathis.img
echo ""
echo "Disk layout:"
echo "  LBA 0:      Boot sector (512B)"
echo "  LBA 1-8:    Stage2 (4KB)"
echo "  LBA 9-1032: Kernel (512KB)"
echo "  LBA 1033+:  Filesystem (available)"
echo ""
echo "Run: qemu-system-x86_64 -hda boot/mathis.img -m 128M"
