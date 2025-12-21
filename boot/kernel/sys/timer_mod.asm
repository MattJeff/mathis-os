; ============================================================================
; TIMER_MOD.ASM - Timer Utilities Module
; ============================================================================
; High-level timer functions: get_ticks, sleep_ms, delay
; PIT runs at 100Hz (10ms per tick)
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
TICKS_PER_SECOND        equ 100         ; PIT at 100Hz
MS_PER_TICK             equ 10          ; 10ms per tick

; ============================================================================
; EXPORTS
; ============================================================================
global get_ticks
global sleep_ms
global sleep_ticks
global ms_to_ticks
global ticks_to_ms

; ============================================================================
; IMPORTS
; ============================================================================
extern tick_count

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; get_ticks - Get current system tick count
; Output: RAX = current tick count (64-bit)
; ----------------------------------------------------------------------------
get_ticks:
    mov rax, [tick_count]
    ret

; ----------------------------------------------------------------------------
; sleep_ms - Sleep for specified milliseconds
; Input: EDI = milliseconds to sleep
; Note: Minimum granularity is 10ms (1 tick)
; ----------------------------------------------------------------------------
sleep_ms:
    push rbx
    push rcx

    ; Convert ms to ticks: ticks = (ms + 9) / 10
    ; +9 for rounding up
    mov eax, edi
    add eax, MS_PER_TICK - 1
    xor edx, edx
    mov ecx, MS_PER_TICK
    div ecx
    mov ecx, eax                        ; ECX = ticks to wait

    ; Get current tick
    mov rbx, [tick_count]
    add rbx, rcx                        ; RBX = target tick

.wait:
    hlt                                 ; Wait for interrupt
    cmp [tick_count], rbx
    jb .wait                            ; Loop until tick_count >= target

    pop rcx
    pop rbx
    ret

; ----------------------------------------------------------------------------
; sleep_ticks - Sleep for specified number of ticks
; Input: EDI = ticks to sleep (1 tick = 10ms)
; ----------------------------------------------------------------------------
sleep_ticks:
    push rbx

    mov rbx, [tick_count]
    add rbx, rdi                        ; RBX = target tick

.wait:
    hlt
    cmp [tick_count], rbx
    jb .wait

    pop rbx
    ret

; ----------------------------------------------------------------------------
; ms_to_ticks - Convert milliseconds to ticks
; Input: EDI = milliseconds
; Output: EAX = ticks
; ----------------------------------------------------------------------------
ms_to_ticks:
    mov eax, edi
    add eax, MS_PER_TICK - 1            ; Round up
    xor edx, edx
    mov ecx, MS_PER_TICK
    div ecx
    ret

; ----------------------------------------------------------------------------
; ticks_to_ms - Convert ticks to milliseconds
; Input: EDI = ticks
; Output: EAX = milliseconds
; ----------------------------------------------------------------------------
ticks_to_ms:
    mov eax, edi
    imul eax, MS_PER_TICK
    ret
