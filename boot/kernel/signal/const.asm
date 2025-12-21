; ============================================================================
; SIGNAL/CONST.ASM - Signal constants (POSIX-like)
; ============================================================================
; Single responsibility: Define signal numbers and structure offsets
; Dependencies: MAX_PROCESSES from scheduler.asm
; ============================================================================

; Signal numbers (1-31, 0 reserved)
SIG_NONE        equ 0
SIGHUP          equ 1
SIGINT          equ 2
SIGQUIT         equ 3
SIGILL          equ 4
SIGTRAP         equ 5
SIGABRT         equ 6
SIGBUS          equ 7
SIGFPE          equ 8
SIGKILL         equ 9
SIGUSR1         equ 10
SIGSEGV         equ 11
SIGUSR2         equ 12
SIGPIPE         equ 13
SIGALRM         equ 14
SIGTERM         equ 15
SIGCHLD         equ 17
SIGCONT         equ 18
SIGSTOP         equ 19
SIGTSTP         equ 20

; Handler constants
SIG_DFL         equ 0
SIG_IGN         equ 1

; Limits
SIG_MAX         equ 32

; Signal entry structure (per process):
;   Offset 0:   pending bitmap (4 bytes)
;   Offset 4:   blocked mask (4 bytes)
;   Offset 8:   handlers[32] (32 * 8 = 256 bytes)
;   Total: 264 bytes per process
SIG_OFF_PENDING     equ 0
SIG_OFF_MASK        equ 4
SIG_OFF_HANDLERS    equ 8
SIG_ENTRY_SIZE      equ 264

; Table size: MAX_PROCESSES * SIG_ENTRY_SIZE = 8 * 264 = 2112 bytes
SIG_TABLE_SIZE      equ 2112
