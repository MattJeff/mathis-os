; ============================================================================
; PIPE_CONST.ASM - Pipe structure constants
; ============================================================================
; Single responsibility: Define pipe structure offsets
; ============================================================================

[BITS 64]

; Pipe structure (64 bytes)
PIPE_READ_FD    equ 0       ; 4 bytes - read file descriptor
PIPE_WRITE_FD   equ 4       ; 4 bytes - write file descriptor
PIPE_BUFFER     equ 8       ; 8 bytes - buffer address
PIPE_SIZE       equ 16      ; 4 bytes - buffer size
PIPE_HEAD       equ 20      ; 4 bytes - write position
PIPE_TAIL       equ 24      ; 4 bytes - read position
PIPE_COUNT      equ 28      ; 4 bytes - bytes in buffer
PIPE_READERS    equ 32      ; 4 bytes - reader count
PIPE_WRITERS    equ 36      ; 4 bytes - writer count
PIPE_FLAGS      equ 40      ; 4 bytes - flags

PIPE_STRUCT_SIZE    equ 64
PIPE_BUFFER_SIZE    equ 4096    ; 4KB buffer
MAX_PIPES           equ 16
PIPE_FD_BASE        equ 100     ; Base FD number for pipes
