; ============================================================================
; MM_DATA.ASM - Memory Management Data Section
; ============================================================================
; All data variables for the memory management subsystem
; This file should be included in the DATA section of go64.asm
; ============================================================================

; ============================================================================
; PMM DATA - Physical Memory Manager
; ============================================================================
pmm_free_pages:     dq 0                ; Count of free pages
pmm_total_pages:    dq 0                ; Total pages in system

; ============================================================================
; VMM DATA - Virtual Memory Manager
; ============================================================================
vmm_pml4:           dq 0                ; Current PML4 physical address

; ============================================================================
; SLAB DATA - Slab Allocator
; ============================================================================
; Cache heads (one pointer per size class: 32, 64, 128, 256, 512, 1024, 2048)
slab_caches:        times 7 dq 0

; Object sizes table (must match SLAB_CACHE_COUNT)
slab_sizes:         dd 32, 64, 128, 256, 512, 1024, 2048

; ============================================================================
; PAGE FAULT DATA
; ============================================================================
pf_fault_addr:      dq 0                ; Last faulting address
pf_error_code:      dq 0                ; Last error code
pf_count:           dq 0                ; Page fault counter
