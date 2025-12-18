; ============================================================================
; MathisOS - Ring 3 User Mode Support
; ============================================================================
; User mode transition and demo processes
; - switch_to_ring3: Transition kernel -> user mode
; - user_process_demo: Example user-space program
; - demo_process_*: Background kernel tasks for multitasking demo
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; DEMO PROCESSES - Background tasks for multitasking demonstration
; ════════════════════════════════════════════════════════════════════════════

; Demo process 1 - Simple infinite loop (register only)
demo_process_1:
.loop1:
    inc rbx
    jmp .loop1

; Demo process 2 - Simple infinite loop (register only)
demo_process_2:
.loop2:
    inc r12
    jmp .loop2

; ════════════════════════════════════════════════════════════════════════════
; SWITCH TO RING 3 (User Mode)
; ════════════════════════════════════════════════════════════════════════════
; Input:
;   RDI = user entry point (address of user code)
;   RSI = user stack pointer (top of user stack)
; ════════════════════════════════════════════════════════════════════════════
switch_to_ring3:
    cli                             ; Disable interrupts during switch

    ; Build iretq stack frame to "return" to Ring 3
    push USER_DATA_SEL              ; SS (user data selector with RPL=3)
    push rsi                        ; RSP (user stack)
    pushfq                          ; RFLAGS
    or qword [rsp], 0x200           ; Set IF (interrupts enabled)
    push USER_CODE_SEL              ; CS (user code selector with RPL=3)
    push rdi                        ; RIP (user entry point)

    ; Clear registers for clean user state
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    xor rdx, rdx
    xor rsi, rsi
    xor rdi, rdi
    xor rbp, rbp
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11
    xor r12, r12
    xor r13, r13
    xor r14, r14
    xor r15, r15

    iretq                           ; "Return" to user mode

; ════════════════════════════════════════════════════════════════════════════
; USER-MODE DEMO PROCESS
; ════════════════════════════════════════════════════════════════════════════
; This code runs in Ring 3! It can only use syscalls to interact with kernel.
; Demonstrates: syscalls, pixel drawing, yielding, sleeping
; ════════════════════════════════════════════════════════════════════════════
user_process_demo:
    ; Running in Ring 3 now!
    ; Get our PID via syscall
    mov rax, SYS_GETPID             ; syscall 11
    int 0x80                        ; Returns PID in RAX

    ; Draw a pixel pattern using syscalls to prove we're in user mode
    mov r12, 10                     ; x position
    mov r13, 180                    ; y position (near bottom)
    mov r14, 0                      ; color counter

.user_loop:
    ; sys_putpixel: draw pixel at (x, y) with color
    mov rax, SYS_PUTPIXEL           ; syscall 40
    mov rdi, r12                    ; x
    mov rsi, r13                    ; y
    mov rdx, r14                    ; color
    int 0x80

    ; Move to next position
    inc r12
    cmp r12, 300
    jl .no_wrap
    mov r12, 10
    inc r14                         ; Next color
.no_wrap:

    ; Yield to let other processes run
    mov rax, SYS_YIELD              ; syscall 18
    int 0x80

    ; Small delay using sleep syscall (10ms)
    mov rax, SYS_SLEEP              ; syscall 17
    mov rdi, 10                     ; 10 milliseconds
    int 0x80

    jmp .user_loop

; ════════════════════════════════════════════════════════════════════════════
; USER STACK AREA
; ════════════════════════════════════════════════════════════════════════════
; Must be in mapped memory (within first 32MB)
align 16
user_stack_bottom:
    times 4096 db 0                 ; 4KB user stack
user_stack_top:
