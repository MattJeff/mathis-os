; ============================================================================
; PMM_CONST.ASM - Physical Memory Manager Constants
; ============================================================================
; Bitmap-based page frame allocator constants
; ============================================================================

[BITS 64]

; ============================================================================
; PAGE CONSTANTS
; ============================================================================
PAGE_SIZE           equ 4096            ; 4KB pages
PAGE_SHIFT          equ 12              ; log2(PAGE_SIZE)

; ============================================================================
; BITMAP CONFIGURATION
; ============================================================================
; Bitmap at 1MB mark, 128KB size = 1M bits = 4GB addressable
PMM_BITMAP_ADDR     equ 0x100000        ; 1MB mark
PMM_BITMAP_SIZE     equ 0x20000         ; 128KB

; ============================================================================
; RESERVED MEMORY RANGES
; ============================================================================
PMM_RESERVED_START  equ 0x000000        ; Start of reserved memory
PMM_RESERVED_END    equ 0x200000        ; 2MB (kernel + bitmap)

; ============================================================================
; BITMAP OPERATIONS
; ============================================================================
PMM_BIT_FREE        equ 0               ; Bit value for free page
PMM_BIT_USED        equ 1               ; Bit value for used page
BITS_PER_QWORD      equ 64              ; Bits per qword
QWORD_SHIFT         equ 6               ; log2(64) for division
BIT_MASK            equ 0x3F            ; 63 = modulo 64 mask

; ============================================================================
; E820 MEMORY TYPES (shared with e820.asm)
; ============================================================================
E820_TYPE_USABLE    equ 1               ; Usable RAM
