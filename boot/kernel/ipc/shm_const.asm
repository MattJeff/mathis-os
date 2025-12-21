; ============================================================================
; SHM_CONST.ASM - Shared memory structure constants
; ============================================================================
; Single responsibility: Define SHM structure offsets
; ============================================================================

[BITS 64]

; Shared memory region structure (64 bytes)
SHM_KEY         equ 0       ; 8 bytes - unique key
SHM_ADDR        equ 8       ; 8 bytes - physical address
SHM_SIZE        equ 16      ; 8 bytes - size in bytes
SHM_REFCOUNT    equ 24      ; 4 bytes - attached processes
SHM_FLAGS       equ 28      ; 4 bytes - permissions
SHM_OWNER       equ 32      ; 2 bytes - owner PID
SHM_RESERVED    equ 34      ; 30 bytes padding

SHM_STRUCT_SIZE equ 64
MAX_SHM_REGIONS equ 16

; SHM flags
SHM_RDONLY      equ 0x01    ; Read-only access
SHM_RND         equ 0x02    ; Round address
