; ============================================================================
; THREAD_CONST.ASM - Thread Control Block constants
; ============================================================================
; Single responsibility: Define TCB structure offsets
; ============================================================================

[BITS 64]

; Thread Control Block (128 bytes)
TCB_TID         equ 0       ; 2 bytes - thread ID
TCB_PID         equ 2       ; 2 bytes - parent process ID
TCB_STATE       equ 4       ; 1 byte - state (uses PROC_STATE_*)
TCB_PRIORITY    equ 5       ; 1 byte - priority
TCB_FLAGS       equ 6       ; 2 bytes - flags

TCB_RSP         equ 8       ; 8 bytes - stack pointer
TCB_RIP         equ 16      ; 8 bytes - instruction pointer
TCB_RFLAGS      equ 24      ; 8 bytes - flags register

TCB_STACK_BASE  equ 32      ; 8 bytes - stack base address
TCB_STACK_SIZE  equ 40      ; 4 bytes - stack size
TCB_ENTRY       equ 48      ; 8 bytes - entry point
TCB_ARG         equ 56      ; 8 bytes - thread argument

TCB_SIZE        equ 128
MAX_THREADS     equ 32

; Default stack size for kernel threads
THREAD_DEFAULT_STACK    equ 4096    ; 4KB
