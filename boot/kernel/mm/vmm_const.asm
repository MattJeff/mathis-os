; ============================================================================
; VMM_CONST.ASM - Virtual Memory Manager Constants
; ============================================================================
; 4-Level paging constants for x86-64
; ============================================================================

[BITS 64]

; ============================================================================
; PAGE TABLE ENTRY FLAGS
; ============================================================================
PTE_PRESENT         equ (1 << 0)        ; Page is present
PTE_WRITE           equ (1 << 1)        ; Page is writable
PTE_USER            equ (1 << 2)        ; User accessible
PTE_PWT             equ (1 << 3)        ; Write-through caching
PTE_PCD             equ (1 << 4)        ; Cache disable
PTE_ACCESSED        equ (1 << 5)        ; Page has been accessed
PTE_DIRTY           equ (1 << 6)        ; Page has been written
PTE_HUGE            equ (1 << 7)        ; 2MB/1GB page (PS bit)
PTE_GLOBAL          equ (1 << 8)        ; Global page (TLB persist)
PTE_NX              equ (1 << 63)       ; No execute (if enabled)

; ============================================================================
; COMMON FLAG COMBINATIONS
; ============================================================================
PTE_KERNEL_RW       equ (PTE_PRESENT | PTE_WRITE)
PTE_KERNEL_RO       equ (PTE_PRESENT)
PTE_USER_RW         equ (PTE_PRESENT | PTE_WRITE | PTE_USER)
PTE_USER_RO         equ (PTE_PRESENT | PTE_USER)

; ============================================================================
; ADDRESS MASKS
; ============================================================================
PTE_ADDR_MASK       equ 0x000FFFFFFFFFF000  ; Physical address bits
PTE_FLAGS_MASK      equ 0xFFF0000000000FFF  ; Flag bits

; ============================================================================
; VIRTUAL ADDRESS LAYOUT (48-bit canonical)
; ============================================================================
; [Sign:16][PML4:9][PDPT:9][PD:9][PT:9][Offset:12]
VMM_PML4_SHIFT      equ 39
VMM_PDPT_SHIFT      equ 30
VMM_PD_SHIFT        equ 21
VMM_PT_SHIFT        equ 12
VMM_INDEX_MASK      equ 0x1FF               ; 9 bits = 512 entries

; ============================================================================
; KERNEL/USER SPACE SPLIT
; ============================================================================
; Kernel: 0xFFFF800000000000 - 0xFFFFFFFFFFFFFFFF (upper half)
; User:   0x0000000000000000 - 0x00007FFFFFFFFFFF (lower half)
KERNEL_VIRT_BASE    equ 0xFFFF800000000000
USER_SPACE_END      equ 0x00007FFFFFFFFFFF
