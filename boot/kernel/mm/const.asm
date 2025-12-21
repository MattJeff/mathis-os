; ============================================================================
; CONST.ASM - Memory Management Constants
; ============================================================================
; Shared constants for all memory management modules
; No code, no data - only EQU definitions
; ============================================================================

[BITS 64]

; ============================================================================
; PAGE CONSTANTS
; ============================================================================
PAGE_SIZE               equ 0x1000          ; 4KB pages
PAGE_SHIFT              equ 12              ; log2(PAGE_SIZE)
PAGE_MASK               equ ~(PAGE_SIZE - 1)

; ============================================================================
; PHYSICAL MEMORY LAYOUT
; ============================================================================
; 0x000000 - 0x100000  : Reserved (BIOS, VGA, etc.)
; 0x100000 - 0x200000  : Kernel code/data (1MB)
; 0x200000 - 0x400000  : PMM bitmap (2MB)
; 0x400000 - 0x1400000 : Heap (16MB)
; 0x1400000+           : Free physical pages

KERNEL_START            equ 0x10000
KERNEL_END              equ 0x100000

PMM_BITMAP_ADDR         equ 0x200000        ; Physical bitmap location
PMM_BITMAP_SIZE         equ 0x200000        ; 2MB for bitmap (covers 64GB)
PMM_MAX_PAGES           equ PMM_BITMAP_SIZE * 8

HEAP_START              equ 0x400000        ; 4MB
HEAP_SIZE               equ 0x1000000       ; 16MB
HEAP_END                equ HEAP_START + HEAP_SIZE

FREE_MEM_START          equ 0x1400000       ; 20MB - start of free pages

; ============================================================================
; HEAP BLOCK CONSTANTS
; ============================================================================
BLOCK_HEADER_SIZE       equ 8
BLOCK_MIN_SIZE          equ 32
BLOCK_ALIGNMENT         equ 16
BLOCK_FREE              equ 1
BLOCK_SIZE_MASK         equ ~0xF

; ============================================================================
; PAGE TABLE FLAGS
; ============================================================================
PTE_PRESENT             equ 0x01
PTE_WRITE               equ 0x02
PTE_USER                equ 0x04
PTE_PWT                 equ 0x08            ; Write-through
PTE_PCD                 equ 0x10            ; Cache disable
PTE_ACCESSED            equ 0x20
PTE_DIRTY               equ 0x40
PTE_HUGE                equ 0x80            ; 2MB page (in PD)
PTE_GLOBAL              equ 0x100
PTE_NX                  equ (1 << 63)       ; No execute

; Common combinations
PTE_KERNEL_RW           equ PTE_PRESENT | PTE_WRITE
PTE_KERNEL_RO           equ PTE_PRESENT
PTE_USER_RW             equ PTE_PRESENT | PTE_WRITE | PTE_USER
PTE_USER_RO             equ PTE_PRESENT | PTE_USER

; ============================================================================
; SLAB CONSTANTS
; ============================================================================
SLAB_CACHE_COUNT        equ 7               ; Number of size classes
SLAB_MIN_SIZE           equ 32
SLAB_MAX_SIZE           equ 2048

; ============================================================================
; E820 MEMORY MAP
; ============================================================================
E820_MAP_ADDR           equ 0x8000          ; Where BIOS stores E820 map
E820_MAX_ENTRIES        equ 32
E820_ENTRY_SIZE         equ 24

; E820 memory types
E820_TYPE_USABLE        equ 1
E820_TYPE_RESERVED      equ 2
E820_TYPE_ACPI_RECLAIM  equ 3
E820_TYPE_ACPI_NVS      equ 4
E820_TYPE_BAD           equ 5
