; ============================================================================
; SLAB_CONST.ASM - Slab Allocator Constants
; ============================================================================
; Fixed-size object allocator for common allocation sizes
; ============================================================================

[BITS 64]

; ============================================================================
; SLAB SIZE CLASSES
; ============================================================================
SLAB_SIZE_32        equ 0
SLAB_SIZE_64        equ 1
SLAB_SIZE_128       equ 2
SLAB_SIZE_256       equ 3
SLAB_SIZE_512       equ 4
SLAB_SIZE_1024      equ 5
SLAB_SIZE_2048      equ 6
SLAB_CACHE_COUNT    equ 7

; ============================================================================
; SLAB HEADER STRUCTURE
; ============================================================================
; Located at start of each slab page (4KB)
; [next_slab:8][free_list:8][used_count:4][obj_size:4][cache_idx:4][pad:4]
SLAB_HDR_NEXT       equ 0               ; Pointer to next slab
SLAB_HDR_FREE       equ 8               ; Free list head
SLAB_HDR_USED       equ 16              ; Used object count
SLAB_HDR_SIZE       equ 20              ; Object size in this slab
SLAB_HDR_CACHE      equ 24              ; Cache index
SLAB_HEADER_SIZE    equ 32              ; Total header size (aligned)

; ============================================================================
; OBJECT SIZES FOR EACH CACHE
; ============================================================================
; Index 0: 32 bytes
; Index 1: 64 bytes
; Index 2: 128 bytes
; Index 3: 256 bytes
; Index 4: 512 bytes
; Index 5: 1024 bytes
; Index 6: 2048 bytes
