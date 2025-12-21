; ════════════════════════════════════════════════════════════════════════════
; SCHEDULER.ASM - Preemptive Multitasking for MATHIS OS 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Features:
; - Process Control Block (PCB) structure
; - Round-robin scheduler with preemption
; - Context switching (save/restore all 64-bit registers)
; - Process creation, termination, and management
; - Time slice: 10 timer ticks (100ms at 100Hz)
; ════════════════════════════════════════════════════════════════════════════

; Process states
PROC_STATE_FREE     equ 0       ; Slot available
PROC_STATE_READY    equ 1       ; Ready to run
PROC_STATE_RUNNING  equ 2       ; Currently executing
PROC_STATE_BLOCKED  equ 3       ; Waiting for event
PROC_STATE_ZOMBIE   equ 4       ; Terminated, waiting cleanup

; Scheduler constants
MAX_PROCESSES       equ 8       ; Maximum concurrent processes
TIME_SLICE          equ 10      ; Timer ticks per time slice (100ms)
PROC_STACK_SIZE     equ 4096    ; 4KB stack per process

; PCB Structure (256 bytes per process for alignment)
; Offset  Size  Field
; 0x00    8     RAX
; 0x08    8     RBX
; 0x10    8     RCX
; 0x18    8     RDX
; 0x20    8     RSI
; 0x28    8     RDI
; 0x30    8     RBP
; 0x38    8     RSP
; 0x40    8     R8
; 0x48    8     R9
; 0x50    8     R10
; 0x58    8     R11
; 0x60    8     R12
; 0x68    8     R13
; 0x70    8     R14
; 0x78    8     R15
; 0x80    8     RIP
; 0x88    8     RFLAGS
; 0x90    8     CS (code segment)
; 0x98    8     SS (stack segment)
; 0xA0    1     State
; 0xA1    1     Priority
; 0xA2    2     PID
; 0xA4    4     Ticks remaining
; 0xA8    8     Stack base
; 0xB0    8     Entry point
; 0xB8    8     Parent PID
; 0xC0    32    Name (32 chars)
; 0xE0    32    Reserved

PCB_RAX         equ 0x00
PCB_RBX         equ 0x08
PCB_RCX         equ 0x10
PCB_RDX         equ 0x18
PCB_RSI         equ 0x20
PCB_RDI         equ 0x28
PCB_RBP         equ 0x30
PCB_RSP         equ 0x38
PCB_R8          equ 0x40
PCB_R9          equ 0x48
PCB_R10         equ 0x50
PCB_R11         equ 0x58
PCB_R12         equ 0x60
PCB_R13         equ 0x68
PCB_R14         equ 0x70
PCB_R15         equ 0x78
PCB_RIP         equ 0x80
PCB_RFLAGS      equ 0x88
PCB_CS          equ 0x90
PCB_SS          equ 0x98
PCB_STATE       equ 0xA0
PCB_PRIORITY    equ 0xA1
PCB_PID         equ 0xA2
PCB_TICKS       equ 0xA4
PCB_STACK_BASE  equ 0xA8
PCB_ENTRY       equ 0xB0
PCB_PARENT      equ 0xB8
PCB_NAME        equ 0xC0
PCB_SIZE        equ 0x100       ; 256 bytes

; Process stacks start at 0x200000 (2MB)
PROC_STACK_BASE equ 0x200000

; ════════════════════════════════════════════════════════════════════════════
; CODE SECTION
; ════════════════════════════════════════════════════════════════════════════
section .text

; ════════════════════════════════════════════════════════════════════════════
; SCHEDULER INITIALIZATION
; ════════════════════════════════════════════════════════════════════════════
scheduler_init:
    push rax
    push rcx
    push rdi

    ; Clear process table
    mov rdi, process_table
    mov rcx, MAX_PROCESSES * PCB_SIZE / 8
    xor rax, rax
    rep stosq

    ; Initialize scheduler variables
    mov byte [scheduler_enabled], 0
    mov dword [current_pid], 0
    mov dword [next_pid], 1
    mov qword [current_process], 0
    mov qword [scheduler_ticks], 0

    ; Create idle process (PID 0) - runs when no other process ready
    mov rdi, process_table
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    mov byte [rdi + PCB_PRIORITY], 0xFF          ; Lowest priority
    mov word [rdi + PCB_PID], 0
    mov dword [rdi + PCB_TICKS], TIME_SLICE
    mov qword [rdi + PCB_ENTRY], idle_process
    mov qword [rdi + PCB_STACK_BASE], 0x90000    ; Use kernel stack
    mov qword [rdi + PCB_RSP], 0x90000
    mov qword [rdi + PCB_RIP], idle_process
    mov qword [rdi + PCB_RFLAGS], 0x202          ; IF=1
    mov qword [rdi + PCB_CS], 0x08               ; Code segment
    mov qword [rdi + PCB_SS], 0x10               ; Data segment

    ; Copy idle process name
    lea rsi, [str_idle_proc]
    lea rdi, [process_table + PCB_NAME]
    mov rcx, 8
.copy_name:
    lodsb
    stosb
    loop .copy_name

    mov qword [current_process], process_table

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; IDLE PROCESS - Runs when no other process is ready
; ════════════════════════════════════════════════════════════════════════════
idle_process:
    hlt
    jmp idle_process

; ════════════════════════════════════════════════════════════════════════════
; CREATE PROCESS - Create a new process
; Input: RDI = entry point, RSI = name string pointer
; Output: EAX = PID (or -1 on error)
; ════════════════════════════════════════════════════════════════════════════
create_process:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    mov r8, rdi                             ; Save entry point
    mov r9, rsi                             ; Save name pointer

    ; Find free slot in process table
    mov rdi, process_table
    xor ecx, ecx                            ; Slot index

.find_slot:
    cmp ecx, MAX_PROCESSES
    jge .no_slot

    cmp byte [rdi + PCB_STATE], PROC_STATE_FREE
    je .found_slot

    add rdi, PCB_SIZE
    inc ecx
    jmp .find_slot

.no_slot:
    mov eax, -1
    jmp .create_done

.found_slot:
    ; Clear the PCB
    push rdi
    push rcx
    mov rcx, PCB_SIZE / 8
    xor rax, rax
    rep stosq
    pop rcx
    pop rdi

    ; Assign PID
    mov eax, [next_pid]
    mov [rdi + PCB_PID], ax
    inc dword [next_pid]

    ; Setup state
    mov byte [rdi + PCB_STATE], PROC_STATE_READY
    mov byte [rdi + PCB_PRIORITY], 128      ; Default priority
    mov dword [rdi + PCB_TICKS], TIME_SLICE

    ; Calculate stack for this process
    mov rax, rcx                            ; Slot index
    inc rax                                 ; +1 (slot 0 uses kernel stack)
    shl rax, 12                             ; * 4096 (stack size)
    add rax, PROC_STACK_BASE
    mov [rdi + PCB_STACK_BASE], rax

    ; Setup initial stack pointer (top of stack)
    add rax, PROC_STACK_SIZE - 8
    mov [rdi + PCB_RSP], rax

    ; Setup entry point
    mov [rdi + PCB_ENTRY], r8
    mov [rdi + PCB_RIP], r8

    ; DEBUG: Magic value pour confirmer le context switch
    mov rax, 0xDEADBEEFCAFEBABE
    mov [rdi + PCB_RAX], rax

    ; Setup flags (interrupts enabled)
    mov qword [rdi + PCB_RFLAGS], 0x202

    ; Setup segments
    mov qword [rdi + PCB_CS], 0x08
    mov qword [rdi + PCB_SS], 0x10

    ; Copy process name
    push rdi
    lea rdi, [rdi + PCB_NAME]
    mov rsi, r9
    mov rcx, 31
.copy_proc_name:
    lodsb
    test al, al
    jz .name_done
    stosb
    loop .copy_proc_name
.name_done:
    mov byte [rdi], 0
    pop rdi

    ; Return PID
    movzx eax, word [rdi + PCB_PID]

.create_done:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EXIT PROCESS - Terminate current process
; ════════════════════════════════════════════════════════════════════════════
exit_process:
    cli
    mov rdi, [current_process]

    ; Don't allow killing idle process
    cmp word [rdi + PCB_PID], 0
    je .cant_exit

    ; Mark as zombie
    mov byte [rdi + PCB_STATE], PROC_STATE_ZOMBIE

    ; Force reschedule
    call scheduler_schedule
    ; Should not return here

.cant_exit:
    sti
    ret

; ════════════════════════════════════════════════════════════════════════════
; KILL PROCESS - Terminate a process by PID
; Input: EDI = PID to kill
; Output: EAX = 0 on success, -1 on error
; ════════════════════════════════════════════════════════════════════════════
kill_process:
    push rbx
    push rcx
    push rdi

    ; Don't allow killing idle process
    test edi, edi
    jz .kill_failed

    ; Find process
    mov rbx, process_table
    xor ecx, ecx

.find_proc:
    cmp ecx, MAX_PROCESSES
    jge .kill_failed

    cmp byte [rbx + PCB_STATE], PROC_STATE_FREE
    je .next_proc
    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    je .next_proc

    movzx eax, word [rbx + PCB_PID]
    cmp eax, edi
    je .found_proc

.next_proc:
    add rbx, PCB_SIZE
    inc ecx
    jmp .find_proc

.found_proc:
    ; Mark as zombie (will be cleaned up by scheduler)
    mov byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    xor eax, eax
    jmp .kill_done

.kill_failed:
    mov eax, -1

.kill_done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SCHEDULER TICK - Called by timer IRQ0
; Decrements time slice, triggers reschedule if needed
; ════════════════════════════════════════════════════════════════════════════
scheduler_tick:
    ; Check if scheduler is enabled
    cmp byte [scheduler_enabled], 1
    jne .tick_done

    inc qword [scheduler_ticks]

    ; Get current process
    mov rdi, [current_process]
    test rdi, rdi
    jz .tick_done

    ; Decrement ticks
    dec dword [rdi + PCB_TICKS]
    jnz .tick_done

    ; Time slice expired - need to reschedule
    ; This will be handled after IRQ returns
    mov byte [need_reschedule], 1

.tick_done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; SCHEDULER SCHEDULE - Select next process to run
; Called when time slice expires or process blocks/exits
; ════════════════════════════════════════════════════════════════════════════
scheduler_schedule:
    push rbx
    push rcx
    push rdx

    ; Clean up zombie processes
    call cleanup_zombies

    ; Find next ready process (round-robin)
    mov rbx, [current_process]
    mov rdx, rbx                            ; Remember starting point

.find_next:
    add rbx, PCB_SIZE

    ; Wrap around
    mov rax, process_table
    add rax, MAX_PROCESSES * PCB_SIZE
    cmp rbx, rax
    jl .check_proc
    mov rbx, process_table

.check_proc:
    ; Back to start = no other ready process
    cmp rbx, rdx
    je .no_switch

    ; Check if ready
    cmp byte [rbx + PCB_STATE], PROC_STATE_READY
    je .found_next
    jmp .find_next

.found_next:
    ; Switch to this process
    mov rdi, rbx
    call switch_to_process
    jmp .schedule_done

.no_switch:
    ; Keep running current process (or idle)
    mov rdi, [current_process]
    mov dword [rdi + PCB_TICKS], TIME_SLICE

.schedule_done:
    mov byte [need_reschedule], 0
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SWITCH TO PROCESS - Context switch to specified process
; Input: RDI = pointer to new process PCB
; ════════════════════════════════════════════════════════════════════════════
switch_to_process:
    push rax
    push rbx

    ; Get current process
    mov rbx, [current_process]

    ; If same process, just reset time slice
    cmp rbx, rdi
    je .same_process

    ; Save current process state (if not zombie)
    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    je .skip_save

    ; Mark current as ready (if it was running)
    cmp byte [rbx + PCB_STATE], PROC_STATE_RUNNING
    jne .skip_save
    mov byte [rbx + PCB_STATE], PROC_STATE_READY

.skip_save:
    ; Update current process pointer
    mov [current_process], rdi
    mov ax, [rdi + PCB_PID]
    mov [current_pid], ax

    ; Mark new process as running
    mov byte [rdi + PCB_STATE], PROC_STATE_RUNNING
    mov dword [rdi + PCB_TICKS], TIME_SLICE

    pop rbx
    pop rax
    ret

.same_process:
    mov dword [rdi + PCB_TICKS], TIME_SLICE
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SAVE CONTEXT - Save all registers to current PCB
; Called from timer ISR before potential switch
; Stack at entry: [return addr] [rax] [rbx] ... (ISR pushed)
; ════════════════════════════════════════════════════════════════════════════
save_context:
    push rax
    push rbx

    mov rbx, [current_process]
    test rbx, rbx
    jz .save_done

    ; Save general registers (some already on stack from ISR)
    mov [rbx + PCB_RCX], rcx
    mov [rbx + PCB_RDX], rdx
    mov [rbx + PCB_RSI], rsi
    mov [rbx + PCB_RDI], rdi
    mov [rbx + PCB_R8], r8
    mov [rbx + PCB_R9], r9
    mov [rbx + PCB_R10], r10
    mov [rbx + PCB_R11], r11
    mov [rbx + PCB_R12], r12
    mov [rbx + PCB_R13], r13
    mov [rbx + PCB_R14], r14
    mov [rbx + PCB_R15], r15

    ; RBP
    mov [rbx + PCB_RBP], rbp

    ; RAX, RBX from stack
    mov rax, [rsp + 8]                      ; Original RAX
    mov [rbx + PCB_RAX], rax
    mov rax, [rsp]                          ; Original RBX
    mov [rbx + PCB_RBX], rax

    ; RSP (adjust for what ISR pushed + iretq frame)
    ; Stack layout: [rbx][rax][ret][rip][cs][rflags][rsp][ss]
    mov rax, rsp
    add rax, 56                             ; Skip to original RSP in iretq frame
    mov rax, [rax]
    mov [rbx + PCB_RSP], rax

    ; Get RIP, CS, RFLAGS from iretq frame
    mov rax, [rsp + 24]                     ; RIP
    mov [rbx + PCB_RIP], rax
    mov rax, [rsp + 32]                     ; CS
    mov [rbx + PCB_CS], rax
    mov rax, [rsp + 40]                     ; RFLAGS
    mov [rbx + PCB_RFLAGS], rax
    mov rax, [rsp + 56]                     ; SS
    mov [rbx + PCB_SS], rax

.save_done:
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; RESTORE CONTEXT - Restore all registers from PCB and return
; Input: RDI = PCB pointer
; This function does not return normally - it iretq's to the process
; ════════════════════════════════════════════════════════════════════════════
restore_context:
    mov rbx, rdi

    ; Setup iretq frame on process's stack
    mov rsp, [rbx + PCB_RSP]
    sub rsp, 40                             ; Space for iretq frame

    ; Build iretq frame: SS, RSP, RFLAGS, CS, RIP
    mov rax, [rbx + PCB_SS]
    mov [rsp + 32], rax
    mov rax, [rbx + PCB_RSP]
    mov [rsp + 24], rax
    mov rax, [rbx + PCB_RFLAGS]
    or rax, 0x200                           ; Ensure IF=1
    mov [rsp + 16], rax
    mov rax, [rbx + PCB_CS]
    mov [rsp + 8], rax
    mov rax, [rbx + PCB_RIP]
    mov [rsp], rax

    ; Restore general registers
    mov rax, [rbx + PCB_RAX]
    mov rcx, [rbx + PCB_RCX]
    mov rdx, [rbx + PCB_RDX]
    mov rsi, [rbx + PCB_RSI]
    mov rdi, [rbx + PCB_RDI]
    mov rbp, [rbx + PCB_RBP]
    mov r8, [rbx + PCB_R8]
    mov r9, [rbx + PCB_R9]
    mov r10, [rbx + PCB_R10]
    mov r11, [rbx + PCB_R11]
    mov r12, [rbx + PCB_R12]
    mov r13, [rbx + PCB_R13]
    mov r14, [rbx + PCB_R14]
    mov r15, [rbx + PCB_R15]
    mov rbx, [rbx + PCB_RBX]

    ; Return to process
    iretq

; ════════════════════════════════════════════════════════════════════════════
; CLEANUP ZOMBIES - Free zombie process slots
; ════════════════════════════════════════════════════════════════════════════
cleanup_zombies:
    push rax
    push rbx
    push rcx

    mov rbx, process_table
    xor ecx, ecx

.cleanup_loop:
    cmp ecx, MAX_PROCESSES
    jge .cleanup_done

    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    jne .next_zombie

    ; Don't free idle process
    cmp word [rbx + PCB_PID], 0
    je .next_zombie

    ; Free this slot
    mov byte [rbx + PCB_STATE], PROC_STATE_FREE

.next_zombie:
    add rbx, PCB_SIZE
    inc ecx
    jmp .cleanup_loop

.cleanup_done:
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; GET PROCESS COUNT - Count active processes
; Output: EAX = number of active processes
; ════════════════════════════════════════════════════════════════════════════
get_process_count:
    push rbx
    push rcx

    mov rbx, process_table
    xor eax, eax
    xor ecx, ecx

.count_loop:
    cmp ecx, MAX_PROCESSES
    jge .count_done

    cmp byte [rbx + PCB_STATE], PROC_STATE_FREE
    je .next_count
    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    je .next_count

    inc eax

.next_count:
    add rbx, PCB_SIZE
    inc ecx
    jmp .count_loop

.count_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; GET PROCESS INFO - Get info about a process by index
; Input: EDI = process index (0-7)
; Output: RAX = PCB pointer (or 0 if invalid/free)
; ════════════════════════════════════════════════════════════════════════════
get_process_info:
    cmp edi, MAX_PROCESSES
    jge .invalid_index

    mov eax, edi
    shl eax, 8                              ; * 256 (PCB_SIZE)
    add rax, process_table

    cmp byte [rax + PCB_STATE], PROC_STATE_FREE
    je .invalid_index

    ret

.invalid_index:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ENABLE SCHEDULER
; ════════════════════════════════════════════════════════════════════════════
scheduler_enable:
    mov byte [scheduler_enabled], 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; DISABLE SCHEDULER
; ════════════════════════════════════════════════════════════════════════════
scheduler_disable:
    mov byte [scheduler_enabled], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; YIELD - Voluntarily give up CPU
; ════════════════════════════════════════════════════════════════════════════
yield_process:
    cli
    mov rdi, [current_process]
    mov dword [rdi + PCB_TICKS], 0          ; Expire time slice
    mov byte [need_reschedule], 1
    sti
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
section .data

align 8

scheduler_enabled:  db 0
need_reschedule:    db 0
                    dw 0                    ; Padding
current_pid:        dd 0
next_pid:           dd 1
current_process:    dq 0
scheduler_ticks:    dq 0

str_idle_proc:      db "idle", 0, 0, 0, 0

; Process table (8 processes * 256 bytes = 2KB)
align 256
process_table:      times MAX_PROCESSES * PCB_SIZE db 0

; ════════════════════════════════════════════════════════════════════════════
; RESTORE TEXT SECTION (for next includes)
; ════════════════════════════════════════════════════════════════════════════
section .text
