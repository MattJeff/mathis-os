; ============================================================================
; MathisOS - Timer ISR with Preemptive Multitasking
; ============================================================================
; IRQ0 handler - system tick + round-robin scheduler
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; TIMER ISR - Preemptive Multitasking
; ════════════════════════════════════════════════════════════════════════════
; Stack on entry (pushed by CPU):
;   +40 SS
;   +32 RSP (original)
;   +24 RFLAGS
;   +16 CS
;   +8  RIP
;   +0  <- RSP points here
; ════════════════════════════════════════════════════════════════════════════
timer_isr64:
    ; ══════════════════════════════════════════════════════════════════
    ; STEP 1: Save ALL general-purpose registers
    ; ══════════════════════════════════════════════════════════════════
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Now stack layout (15 GP regs + 5 CPU = 160 bytes):
    ; +152 SS
    ; +144 RSP (original)
    ; +136 RFLAGS
    ; +128 CS
    ; +120 RIP
    ; +112 RAX
    ; +104 RBX
    ; +96  RCX
    ; +88  RDX
    ; +80  RSI
    ; +72  RDI
    ; +64  RBP
    ; +56  R8
    ; +48  R9
    ; +40  R10
    ; +32  R11
    ; +24  R12
    ; +16  R13
    ; +8   R14
    ; +0   R15 <- RSP

    ; ══════════════════════════════════════════════════════════════════
    ; Increment system tick (for clock)
    ; ══════════════════════════════════════════════════════════════════
    inc qword [tick_count]

    ; Decrement tab debounce counter
    mov eax, [tab_debounce]
    test eax, eax
    jz .no_tab_dec
    dec dword [tab_debounce]
.no_tab_dec:

    ; ══════════════════════════════════════════════════════════════════
    ; Check if scheduler is enabled
    ; ══════════════════════════════════════════════════════════════════
    cmp byte [scheduler_enabled], 0
    je .no_schedule

    ; ══════════════════════════════════════════════════════════════════
    ; Decrement time slice of current process
    ; ══════════════════════════════════════════════════════════════════
    mov rdi, [current_process]
    test rdi, rdi
    jz .no_schedule

    dec dword [rdi + PCB_TICKS]
    jnz .no_schedule            ; Time slice not expired yet

    ; ══════════════════════════════════════════════════════════════════
    ; TIME SLICE EXPIRED - Need to context switch!
    ; ══════════════════════════════════════════════════════════════════

    ; Save current process context to its PCB
    ; RDI already points to current_process PCB

    ; Save registers from stack (offsets match stack layout comment above)
    mov rax, [rsp + 112]        ; RAX from stack
    mov [rdi + PCB_RAX], rax
    mov rax, [rsp + 104]        ; RBX from stack
    mov [rdi + PCB_RBX], rax
    mov rax, [rsp + 96]         ; RCX from stack
    mov [rdi + PCB_RCX], rax
    mov rax, [rsp + 88]         ; RDX from stack
    mov [rdi + PCB_RDX], rax
    mov rax, [rsp + 80]         ; RSI from stack
    mov [rdi + PCB_RSI], rax
    mov rax, [rsp + 72]         ; RDI from stack
    mov [rdi + PCB_RDI], rax
    mov rax, [rsp + 64]         ; RBP from stack
    mov [rdi + PCB_RBP], rax
    mov rax, [rsp + 56]         ; R8 from stack
    mov [rdi + PCB_R8], rax
    mov rax, [rsp + 48]         ; R9 from stack
    mov [rdi + PCB_R9], rax
    mov rax, [rsp + 40]         ; R10 from stack
    mov [rdi + PCB_R10], rax
    mov rax, [rsp + 32]         ; R11 from stack
    mov [rdi + PCB_R11], rax
    mov rax, [rsp + 24]         ; R12 from stack
    mov [rdi + PCB_R12], rax
    mov rax, [rsp + 16]         ; R13 from stack
    mov [rdi + PCB_R13], rax
    mov rax, [rsp + 8]          ; R14 from stack
    mov [rdi + PCB_R14], rax
    mov rax, [rsp + 0]          ; R15 from stack
    mov [rdi + PCB_R15], rax

    ; Save CPU state from iretq frame
    mov rax, [rsp + 120]        ; RIP
    mov [rdi + PCB_RIP], rax
    mov rax, [rsp + 136]        ; RFLAGS
    mov [rdi + PCB_RFLAGS], rax
    mov rax, [rsp + 144]        ; RSP (original)
    mov [rdi + PCB_RSP], rax

    ; Mark current process as READY (it was RUNNING)
    mov byte [rdi + PCB_STATE], PROC_STATE_READY

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 2: Find next READY process (round-robin)
    ; ══════════════════════════════════════════════════════════════════
    mov rbx, rdi                ; RBX = current process (start point)

.find_next:
    add rdi, PCB_SIZE           ; Move to next slot

    ; Wrap around if past end of table
    lea rax, [process_table + MAX_PROCESSES * PCB_SIZE]
    cmp rdi, rax
    jl .check_slot
    mov rdi, process_table      ; Wrap to beginning

.check_slot:
    ; Did we loop back to start?
    cmp rdi, rbx
    je .no_other_process        ; No other ready process found

    ; Is this slot READY?
    cmp byte [rdi + PCB_STATE], PROC_STATE_READY
    jne .find_next              ; No, try next

    ; Found a READY process! Switch to it.
    jmp .do_switch

.no_other_process:
    ; No other process ready - keep running current one
    mov rdi, rbx
    mov dword [rdi + PCB_TICKS], TIME_SLICE
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    jmp .no_schedule

.do_switch:
    ; ══════════════════════════════════════════════════════════════════
    ; STEP 3: Load new process context
    ; ══════════════════════════════════════════════════════════════════

    ; Update current_process pointer
    mov [current_process], rdi

    ; Mark new process as RUNNING
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    mov dword [rdi + PCB_TICKS], TIME_SLICE

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 4: Restore registers and iretq
    ; ══════════════════════════════════════════════════════════════════

    ; Restore iretq frame on stack (offsets match stack layout comment)
    mov rax, [rdi + PCB_RIP]
    mov [rsp + 120], rax        ; RIP
    mov rax, [rdi + PCB_RFLAGS]
    or rax, 0x200               ; Ensure interrupts enabled
    mov [rsp + 136], rax        ; RFLAGS
    mov rax, [rdi + PCB_RSP]
    mov [rsp + 144], rax        ; RSP
    mov qword [rsp + 128], 0x08 ; CS (kernel code)
    mov qword [rsp + 152], 0x10 ; SS (kernel data)

    ; Restore general registers on stack (will be popped)
    mov rax, [rdi + PCB_RAX]
    mov [rsp + 112], rax
    mov rax, [rdi + PCB_RBX]
    mov [rsp + 104], rax
    mov rax, [rdi + PCB_RCX]
    mov [rsp + 96], rax
    mov rax, [rdi + PCB_RDX]
    mov [rsp + 88], rax
    mov rax, [rdi + PCB_RSI]
    mov [rsp + 80], rax
    mov rax, [rdi + PCB_RDI]
    mov [rsp + 72], rax
    mov rax, [rdi + PCB_RBP]
    mov [rsp + 64], rax
    mov rax, [rdi + PCB_R8]
    mov [rsp + 56], rax
    mov rax, [rdi + PCB_R9]
    mov [rsp + 48], rax
    mov rax, [rdi + PCB_R10]
    mov [rsp + 40], rax
    mov rax, [rdi + PCB_R11]
    mov [rsp + 32], rax
    mov rax, [rdi + PCB_R12]
    mov [rsp + 24], rax
    mov rax, [rdi + PCB_R13]
    mov [rsp + 16], rax
    mov rax, [rdi + PCB_R14]
    mov [rsp + 8], rax
    mov rax, [rdi + PCB_R15]
    mov [rsp + 0], rax

.no_schedule:
    ; ══════════════════════════════════════════════════════════════════
    ; Send EOI and return
    ; ══════════════════════════════════════════════════════════════════
    mov al, 0x20
    out 0x20, al

    ; Restore all registers from stack
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ; Return to (possibly new) process
    iretq
