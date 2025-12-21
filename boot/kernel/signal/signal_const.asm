; ============================================================================
; SIGNAL_CONST.ASM - Signal constants (POSIX-like)
; ============================================================================
; Single responsibility: Define signal numbers and constants
; ============================================================================

[BITS 64]

; Signal numbers
SIG_NONE    equ 0       ; No signal
SIGHUP      equ 1       ; Hangup
SIGINT      equ 2       ; Interrupt (Ctrl+C)
SIGQUIT     equ 3       ; Quit
SIGILL      equ 4       ; Illegal instruction
SIGTRAP     equ 5       ; Trace trap
SIGABRT     equ 6       ; Abort
SIGBUS      equ 7       ; Bus error
SIGFPE      equ 8       ; Floating point exception
SIGKILL     equ 9       ; Kill (cannot be caught)
SIGUSR1     equ 10      ; User defined 1
SIGSEGV     equ 11      ; Segmentation fault
SIGUSR2     equ 12      ; User defined 2
SIGPIPE     equ 13      ; Broken pipe
SIGALRM     equ 14      ; Alarm clock
SIGTERM     equ 15      ; Termination
SIGCHLD     equ 17      ; Child status changed
SIGCONT     equ 18      ; Continue
SIGSTOP     equ 19      ; Stop (cannot be caught)
SIGTSTP     equ 20      ; Terminal stop

; Handler constants
SIG_DFL     equ 0       ; Default action
SIG_IGN     equ 1       ; Ignore signal

; Limits
MAX_SIGNALS equ 32      ; Maximum signal number

; Signal table entry size (per process)
; 4 bytes pending bitmap + 4 bytes mask + 32*8 handlers = 264 bytes
SIG_ENTRY_SIZE      equ 264
SIG_PENDING_OFF     equ 0       ; Pending signals bitmap
SIG_MASK_OFF        equ 4       ; Blocked signals mask
SIG_HANDLERS_OFF    equ 8       ; Handler table (32 * 8 bytes)
