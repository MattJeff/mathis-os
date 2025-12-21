; ============================================================================
; PRIORITY.ASM - Priority-based process selection
; ============================================================================
; Single responsibility: Select highest priority READY process
; Uses: process_table, PCB_STATE, PCB_PRIORITY, PCB_SIZE, MAX_PROCESSES
; ============================================================================

[BITS 64]


; ============================================================================
; SCHEDULER_SELECT_PRIORITY - Find highest priority READY process
; ============================================================================
; Input:  none
; Output: RAX = PCB pointer, or 0 if no ready process
; Clobbers: RAX, RCX, RDX (scratch per System V)
; ============================================================================
scheduler_select_priority:
    push rbx
    push r12
    push r13

    xor r12, r12                        ; Best candidate PCB (0 = none)
    mov r13d, 256                       ; Best priority found (256 = worse than any)

    lea rbx, [process_table]
    xor ecx, ecx                        ; Index counter

.scan_loop:
    cmp ecx, MAX_PROCESSES
    jge .scan_done

    ; Skip if not READY
    cmp byte [rbx + PCB_STATE], PROC_STATE_READY
    jne .next_process

    ; Compare priority (lower = better)
    movzx edx, byte [rbx + PCB_PRIORITY]
    cmp edx, r13d
    jge .next_process

    ; New best candidate
    mov r13d, edx
    mov r12, rbx

.next_process:
    add rbx, PCB_SIZE
    inc ecx
    jmp .scan_loop

.scan_done:
    mov rax, r12                        ; Return best candidate (or 0)

    pop r13
    pop r12
    pop rbx
    ret
