; ============================================================================
; MULTIBOOT HEADER - Multiboot 1 Specification
; ============================================================================
; Makes kernel compatible with GRUB and other Multiboot bootloaders.
; Must be within the first 8KB of the kernel binary.
;
; Reference: https://www.gnu.org/software/grub/manual/multiboot/
; ============================================================================

[BITS 32]

; ============================================================================
; MULTIBOOT CONSTANTS (Specification v1)
; ============================================================================

MULTIBOOT_MAGIC         equ 0x1BADB002  ; Magic number for bootloader
MULTIBOOT_BOOTLOADER_MAGIC equ 0x2BADB002  ; Magic passed by bootloader

; Flags bits
MULTIBOOT_FLAG_ALIGN    equ (1 << 0)    ; Align modules on 4KB boundaries
MULTIBOOT_FLAG_MEMINFO  equ (1 << 1)    ; Request memory info
MULTIBOOT_FLAG_VIDEO    equ (1 << 2)    ; Request video mode info

; Combined flags for our kernel
MULTIBOOT_FLAGS         equ (MULTIBOOT_FLAG_ALIGN | MULTIBOOT_FLAG_MEMINFO)

; Checksum must make header sum to zero
MULTIBOOT_CHECKSUM      equ -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

; ============================================================================
; MULTIBOOT HEADER STRUCTURE
; ============================================================================
; This section MUST be placed first in the binary (before .entry)
; The linker script ensures this via section ordering.
; ============================================================================

section .multiboot

; ============================================================================
; LEGACY BOOT TRAMPOLINE
; ============================================================================
; When stage2 jumps to 0x10000, this jump redirects to kernel_entry.
; GRUB scans for the multiboot header and uses ELF entry point instead.
; ============================================================================
legacy_trampoline:
    jmp kernel_entry        ; 5-byte near jump (E9 xx xx xx xx)
    nop                     ; Padding
    nop
    nop

; ============================================================================
; MULTIBOOT HEADER (aligned at offset 8)
; ============================================================================
align 4

multiboot_header:
    dd MULTIBOOT_MAGIC          ; Magic number
    dd MULTIBOOT_FLAGS          ; Flags
    dd MULTIBOOT_CHECKSUM       ; Checksum (magic + flags + checksum = 0)

; ============================================================================
; EXPORTED SYMBOLS
; ============================================================================

global multiboot_header
global MULTIBOOT_BOOTLOADER_MAGIC
