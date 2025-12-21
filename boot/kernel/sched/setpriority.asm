; ============================================================================
; SETPRIORITY.ASM - Syscall to change process priority
; ============================================================================
; Single responsibility: Change priority of current process
; Uses: current_process, PCB_PRIORITY, PRIO_* constants
; ============================================================================

[BITS 64]


; ============================================================================
; SYS_SETPRIORITY - Set priority of current process
; ============================================================================
; Input:  RDI = new priority (0-255, lower = higher priority)
; Output: RAX = 0 success, -1 error (invalid priority)
; Clobbers: RAX (scratch per System V)
; ============================================================================
sys_setpriority:
    ; Validate priority range (0-255 fits in a byte, always valid)
    cmp rdi, 255
    ja .error

    ; Get current process PCB
    mov rax, [current_process]
    test rax, rax
    jz .error

    ; Set priority
    mov [rax + PCB_PRIORITY], dil

    xor eax, eax                        ; Return 0 = success
    ret

.error:
    mov rax, -1                         ; Return -1 = error
    ret

; ============================================================================
; SYS_GETPRIORITY - Get priority of current process
; ============================================================================
; Input:  none
; Output: RAX = current priority (0-255)
; ============================================================================
sys_getpriority:
    mov rax, [current_process]
    test rax, rax
    jz .error_get

    movzx eax, byte [rax + PCB_PRIORITY]
    ret

.error_get:
    mov rax, -1
    ret
