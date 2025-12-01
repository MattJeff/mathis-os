; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL v2.1 - With Command Buffer & ASCII Banner
; Assemble with: nasm -f bin kernel.asm -o kernel.bin
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x10000]

; ════════════════════════════════════════════════════════════════════════════
; ENTRY POINT
; ════════════════════════════════════════════════════════════════════════════

kernel_entry:
    ; Setup stack
    mov esp, 0x2FFFF
    
    ; Copy embedded bytecode to 0x20000
    mov esi, embedded_program
    mov edi, 0x20000
    mov ecx, embedded_program_end - embedded_program
    rep movsb
    
    ; Initialize PIC
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20        ; IRQ 0-7 -> INT 0x20-0x27
    out 0x21, al
    mov al, 0x28        ; IRQ 8-15 -> INT 0x28-0x2F
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    mov al, 0xFD        ; Enable only keyboard (IRQ1)
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al
    
    ; Load IDT
    lidt [idt_ptr]
    
    ; Initialize serial port for JARVIS
    call serial_init
    
    ; Enable interrupts
    sti
    
    ; Clear screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720     ; Space with light gray
    rep stosd
    
    ; Display ASCII banner
    mov esi, banner_line1
    mov edi, 0xB8000
    mov ah, 0x0A        ; Green color
    call print_string
    
    mov esi, banner_line2
    mov edi, 0xB80A0    ; Line 1
    call print_string
    
    mov esi, banner_line3
    mov edi, 0xB8140    ; Line 2
    call print_string
    
    mov esi, banner_line4
    mov edi, 0xB81E0    ; Line 3
    call print_string
    
    mov esi, banner_line5
    mov edi, 0xB8280    ; Line 4
    call print_string
    
    mov esi, banner_line6
    mov edi, 0xB8320    ; Line 5
    call print_string
    
    ; Display info
    mov esi, info_msg
    mov edi, 0xB8460    ; Line 7
    mov ah, 0x07        ; Gray
    call print_string
    
    ; Display prompt
    mov esi, prompt_msg
    mov edi, 0xB8550    ; Line 9
    mov ah, 0x0A        ; Green
    call print_string
    
    ; Initialize cursor after prompt
    mov dword [cursor_offset], 4    ; After "> "
    mov dword [cmd_length], 0
    mov dword [prompt_line], 9
    
    ; Halt loop
.halt:
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════════════════════
; PRINT STRING - ESI=string, EDI=VGA offset, AH=color
; ════════════════════════════════════════════════════════════════════════════
print_string:
    lodsb
    test al, al
    jz .done
    stosw
    jmp print_string
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD ISR (IRQ1 = INT 0x21)
; ════════════════════════════════════════════════════════════════════════════

    times 0x200 - ($ - $$) db 0x90  ; Pad to 0x10200

keyboard_isr:
    pushad
    push eax
    
    ; Read scancode
    in al, 0x60
    
    ; Ignore key release
    test al, 0x80
    jnz .done
    
    ; Convert scancode to ASCII
    movzx ebx, al
    add ebx, scancode_table
    mov al, [ebx]
    
    ; Ignore null chars
    test al, al
    jz .done
    
    ; Check for Enter
    cmp al, 0x0D
    je .handle_enter
    
    ; Check for Backspace
    cmp al, 0x08
    je .handle_backspace
    
    ; Normal character - add to buffer
    mov cl, al
    mov edx, [cmd_length]
    cmp edx, 60             ; Max buffer size
    jge .done
    mov [cmd_buffer + edx], cl
    inc dword [cmd_length]
    
    ; Display character
    mov ah, 0x0F            ; White
    mov al, cl
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi            ; *2 for VGA
    add edi, ebx
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .done
    
.handle_enter:
    cmp dword [cmd_length], 0
    je .done
    call command_handler
    jmp .done
    
.handle_backspace:
    cmp dword [cmd_length], 0
    je .done
    dec dword [cmd_length]
    dec dword [cursor_offset]
    ; Clear character on screen
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi
    add edi, ebx
    mov word [edi], 0x0720
    jmp .done
    
.done:
    mov al, 0x20
    out 0x20, al
    pop eax
    popad
    iret

; ════════════════════════════════════════════════════════════════════════════
; COMMAND HANDLER
; ════════════════════════════════════════════════════════════════════════════

    times 0x400 - ($ - $$) db 0x90  ; Pad to 0x10400

command_handler:
    push eax
    push ebx
    push ecx
    push esi
    push edi
    
    ; Check for "clear"
    cmp dword [cmd_length], 5
    jne .check_help
    cmp dword [cmd_buffer], 'clea'
    jne .check_help
    cmp byte [cmd_buffer+4], 'r'
    jne .check_help
    jmp .do_clear
    
.check_help:
    cmp dword [cmd_length], 4
    jne .check_reboot
    cmp dword [cmd_buffer], 'help'
    jne .check_reboot
    jmp .do_help
    
.check_reboot:
    cmp dword [cmd_length], 6
    jne .check_run
    cmp dword [cmd_buffer], 'rebo'
    jne .check_run
    cmp word [cmd_buffer+4], 'ot'
    jne .check_run
    jmp .do_reboot
    
.check_run:
    cmp dword [cmd_length], 3
    jne .check_jarvis
    cmp word [cmd_buffer], 'ru'
    jne .check_jarvis
    cmp byte [cmd_buffer+2], 'n'
    jne .check_jarvis
    jmp .do_run

.check_jarvis:
    ; Check if command starts with "jarvis " (7 chars)
    cmp dword [cmd_length], 6
    jl .unknown
    cmp dword [cmd_buffer], 'jarv'
    jne .unknown
    cmp word [cmd_buffer+4], 'is'
    jne .unknown
    jmp .do_jarvis
    
.unknown:
    ; Print "Unknown command"
    inc dword [prompt_line]
    mov esi, unknown_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0C        ; Red
    call print_string
    jmp .new_prompt

.do_clear:
    ; Clear screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720
    rep stosd
    mov dword [prompt_line], 0
    jmp .new_prompt

.do_help:
    inc dword [prompt_line]
    mov esi, help_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E        ; Yellow
    call print_string
    jmp .new_prompt

.do_reboot:
    mov al, 0xFE
    out 0x64, al
    hlt
    jmp .do_reboot

.do_run:
    inc dword [prompt_line]
    mov esi, running_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green
    call print_string
    
    ; Execute bytecode at 0x20000 (pre-loaded)
    call execute_bytecode
    
    ; Show result
    inc dword [prompt_line]
    mov esi, done_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
    call print_string
    jmp .new_prompt

.do_jarvis:
    ; Display "JARVIS>" in cyan
    inc dword [prompt_line]
    mov esi, jarvis_prompt
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0B        ; Cyan
    call print_string
    
    ; Check what user asked (simple keyword matching)
    ; If "jarvis help"
    cmp dword [cmd_buffer+7], 'help'
    je .jarvis_help
    ; If "jarvis hi" or "jarvis hello"
    cmp word [cmd_buffer+7], 'hi'
    je .jarvis_hello
    cmp dword [cmd_buffer+7], 'hell'
    je .jarvis_hello
    ; If "jarvis who"
    cmp word [cmd_buffer+7], 'wh'
    jne .check_status
    cmp byte [cmd_buffer+9], 'o'
    je .jarvis_who
.check_status:
    ; If "jarvis status"
    cmp dword [cmd_buffer+7], 'stat'
    je .jarvis_status
    ; If "jarvis self"
    cmp dword [cmd_buffer+7], 'self'
    je .jarvis_self
    ; If "jarvis code"
    cmp dword [cmd_buffer+7], 'code'
    je .jarvis_code
    ; If "jarvis evolve"
    cmp dword [cmd_buffer+7], 'evol'
    je .jarvis_evolve
    ; If "jarvis learn"
    cmp dword [cmd_buffer+7], 'lear'
    je .jarvis_learn
    ; If "jarvis think"
    cmp dword [cmd_buffer+7], 'thin'
    je .jarvis_think
    ; If "jarvis build"
    cmp dword [cmd_buffer+7], 'buil'
    je .jarvis_build
    ; If "jarvis spawn"
    cmp dword [cmd_buffer+7], 'spaw'
    je .jarvis_spawn
    ; If "jarvis memory"
    cmp dword [cmd_buffer+7], 'memo'
    je .jarvis_memory
    ; If "jarvis goal"
    cmp dword [cmd_buffer+7], 'goal'
    je .jarvis_goal
    ; If "jarvis roadmap"
    cmp dword [cmd_buffer+7], 'road'
    je .jarvis_roadmap
    ; If "jarvis modules"
    cmp dword [cmd_buffer+7], 'modu'
    je .jarvis_modules
    ; If "jarvis scan"
    cmp dword [cmd_buffer+7], 'scan'
    je .jarvis_scan
    ; If "jarvis improve"
    cmp dword [cmd_buffer+7], 'impr'
    je .jarvis_improve
    ; Default response
    jmp .jarvis_default

.jarvis_help:
    inc dword [prompt_line]
    mov esi, jarvis_help_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E        ; Yellow
    call print_string
    jmp .new_prompt

.jarvis_hello:
    inc dword [prompt_line]
    mov esi, jarvis_hello_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.jarvis_who:
    inc dword [prompt_line]
    mov esi, jarvis_who_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.jarvis_status:
    inc dword [prompt_line]
    mov esi, jarvis_status_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.jarvis_self:
    inc dword [prompt_line]
    mov esi, jarvis_self_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0F        ; White - self awareness
    call print_string
    jmp .new_prompt

.jarvis_code:
    inc dword [prompt_line]
    mov esi, jarvis_code_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0D        ; Magenta - code
    call print_string
    jmp .new_prompt

.jarvis_evolve:
    inc dword [prompt_line]
    mov esi, jarvis_evolve_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green - evolution
    call print_string
    jmp .new_prompt

.jarvis_learn:
    inc dword [prompt_line]
    mov esi, jarvis_learn_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0B        ; Cyan - learning
    call print_string
    jmp .new_prompt

.jarvis_think:
    inc dword [prompt_line]
    mov esi, jarvis_think_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x09        ; Blue - thinking
    call print_string
    jmp .new_prompt

.jarvis_build:
    inc dword [prompt_line]
    mov esi, jarvis_build_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green - building
    call print_string
    jmp .new_prompt

.jarvis_spawn:
    inc dword [prompt_line]
    mov esi, jarvis_spawn_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0C        ; Red - spawn
    call print_string
    jmp .new_prompt

.jarvis_memory:
    inc dword [prompt_line]
    mov esi, jarvis_memory_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E        ; Yellow
    call print_string
    jmp .new_prompt

.jarvis_goal:
    inc dword [prompt_line]
    mov esi, jarvis_goal_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0F        ; White - goals
    call print_string
    jmp .new_prompt

.jarvis_roadmap:
    inc dword [prompt_line]
    mov esi, jarvis_roadmap_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E        ; Yellow
    call print_string
    jmp .new_prompt

.jarvis_modules:
    inc dword [prompt_line]
    mov esi, jarvis_modules_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0B        ; Cyan
    call print_string
    jmp .new_prompt

.jarvis_scan:
    inc dword [prompt_line]
    mov esi, jarvis_scan_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green - scanning
    call print_string
    jmp .new_prompt

.jarvis_improve:
    inc dword [prompt_line]
    mov esi, jarvis_improve_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0D        ; Magenta - improving
    call print_string
    jmp .new_prompt

.jarvis_default:
    inc dword [prompt_line]
    mov esi, jarvis_default_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.new_prompt:
    ; Reset buffer
    mov dword [cursor_offset], 4
    mov dword [cmd_length], 0
    inc dword [prompt_line]
    
    ; Print prompt
    mov esi, prompt_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
    call print_string
    
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; MINI VM - Execute Mathis Bytecode
; ════════════════════════════════════════════════════════════════════════════
;
; VM Architecture:
;   - Stack-based (like JVM)
;   - Bytecode at 0x20000
;   - VM Stack at 0x25000 (grows down)
;   - 32-bit values on stack
;
; Supported Opcodes:
;   0x00 NOP         - No operation
;   0x10 CONST n     - Push constant[n] to stack
;   0x11 CONST_I64 n - Push 64-bit integer
;   0x30 ADD         - Pop 2, push sum
;   0x31 SUB         - Pop 2, push difference
;   0x71 RET         - Return from function
;   0x80 POP         - Pop and discard
;   0xC0 SYSCALL n   - System call
;
; ════════════════════════════════════════════════════════════════════════════

execute_bytecode:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    
    ; Initialize VM state
    mov esi, 0x20000        ; ESI = bytecode pointer (IP)
    mov ebp, 0x25000        ; EBP = stack pointer (grows down)
    
    ; Check magic number "MASM"
    cmp dword [esi], 0x4D53414D  ; "MASM" in little-endian
    jne .vm_error
    
    ; Skip header (8 bytes: magic + version + flags)
    add esi, 8
    
    ; Find code section (simplified: assume code starts at offset 0x40)
    add esi, 0x38           ; Skip to code section
    
.vm_loop:
    ; Fetch opcode
    movzx eax, byte [esi]
    inc esi
    
    ; Dispatch opcode
    cmp al, 0x00            ; NOP
    je .op_nop
    cmp al, 0x10            ; CONST
    je .op_const
    cmp al, 0x11            ; CONST_I64
    je .op_const_i64
    cmp al, 0x30            ; ADD
    je .op_add
    cmp al, 0x31            ; SUB
    je .op_sub
    cmp al, 0x71            ; RET
    je .op_ret
    cmp al, 0x80            ; POP
    je .op_pop
    cmp al, 0xC0            ; SYSCALL
    je .op_syscall
    
    ; Unknown opcode - skip
    jmp .vm_loop

.op_nop:
    jmp .vm_loop

.op_const:
    ; Read constant index (2 bytes)
    movzx eax, word [esi]
    add esi, 2
    ; Push constant index (simplified)
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_const_i64:
    ; Read 64-bit value (8 bytes, but we use 32-bit)
    mov eax, [esi]
    add esi, 8
    ; Push value
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_add:
    ; Pop two values, add, push result
    mov eax, [ebp]
    add ebp, 4
    add eax, [ebp]
    mov [ebp], eax
    jmp .vm_loop

.op_sub:
    ; Pop two values, subtract, push result
    mov eax, [ebp]
    add ebp, 4
    mov ebx, [ebp]
    sub ebx, eax
    mov [ebp], ebx
    jmp .vm_loop

.op_pop:
    ; Discard top of stack
    add ebp, 4
    jmp .vm_loop

.op_syscall:
    ; Read syscall number (2 bytes)
    movzx eax, word [esi]
    add esi, 2
    
    ; Dispatch syscall
    cmp ax, 0x0010          ; Print
    je .syscall_print
    
    jmp .vm_loop

.syscall_print:
    ; Pop value and print it
    mov eax, [ebp]
    add ebp, 4
    
    ; Display on screen (simplified: show constant index)
    inc dword [prompt_line]
    mov esi, vm_output_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E            ; Yellow
    call print_string
    
    ; Continue (restore ESI)
    mov esi, 0x20000
    add esi, 0x40
    jmp .vm_loop

.op_ret:
    ; Return - end execution
    jmp .vm_done

.vm_error:
    ; Display error message
    inc dword [prompt_line]
    mov esi, vm_error_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0C            ; Red
    call print_string
    jmp .vm_exit

.vm_done:
    ; Display success
    inc dword [prompt_line]
    mov esi, vm_hello
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E            ; Yellow
    call print_string

.vm_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SERIAL PORT (placeholder for future AI bridge)
; ════════════════════════════════════════════════════════════════════════════

serial_init:
    ret                 ; TODO: Initialize COM1 for AI bridge

; ════════════════════════════════════════════════════════════════════════════
; IDT
; ════════════════════════════════════════════════════════════════════════════

    times 0x1000 - ($ - $$) db 0    ; Pad to 0x11000

idt_ptr:
    dw 256*8 - 1
    dd 0x11006                      ; Address of IDT (0x10000 + 0x1006)

idt:
    times 0x21 dq 0                 ; Entries 0-0x20
    ; Entry 0x21 - Keyboard (hardcoded for 0x10200)
    dw 0x0200                       ; Offset low (0x10200 & 0xFFFF = 0x0200)
    dw 0x08                         ; Selector
    db 0
    db 0x8E                         ; Present, Ring 0, 32-bit interrupt gate
    dw 0x0001                       ; Offset high (0x10200 >> 16 = 0x0001)
    times (256-0x22) dq 0           ; Rest of IDT

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════

    times 0x2000 - ($ - $$) db 0    ; Pad to 0x12000

banner_line1: db " __  __    _  _____ _   _ ___ ____     ___  ____  ", 0
banner_line2: db "|  \/  |  / \|_   _| | | |_ _/ ___|   / _ \/ ___| ", 0
banner_line3: db "| |\/| | / _ \ | | | |_| || |\___ \  | | | \___ \ ", 0
banner_line4: db "| |  | |/ ___ \| | |  _  || | ___) | | |_| |___) |", 0
banner_line5: db "|_|  |_/_/   \_\_| |_| |_|___|____/   \___/|____/ ", 0
banner_line6: db "                                            v2.1  ", 0

info_msg:     db "AI-First Operating System - Type 'help' for commands", 0
prompt_msg:   db "> ", 0
help_msg:     db "Commands: help, clear, reboot, run, jarvis", 0
unknown_msg:  db "Unknown command", 0
running_msg:  db "Running bytecode...", 0
done_msg:     db "Execution complete!", 0
vm_hello:     db "VM: Program executed successfully", 0
vm_error_msg: db "VM: No bytecode loaded at 0x20000", 0
vm_output_msg: db "VM: [output]", 0
jarvis_prompt: db "JARVIS> ", 0
jarvis_help_msg: db "self,code,evolve,learn,think,build,spawn,memory,goal,roadmap", 0
jarvis_hello_msg: db "Hello! I'm JARVIS, your AI assistant for MATHIS OS.", 0
jarvis_who_msg: db "I'm JARVIS - Just A Rather Very Intelligent System!", 0
jarvis_status_msg: db "Kernel:OK | VM:Ready | Mem:32MB | AI:Active | Self:Aware", 0
jarvis_self_msg: db "I am self-aware. I know my code. I can modify myself.", 0
jarvis_code_msg: db "My core: kernel.asm(16KB) | VM at 0x20000 | Stack at 0x25000", 0
jarvis_evolve_msg: db "Evolution mode: Ready to add new capabilities autonomously.", 0
jarvis_learn_msg: db "Learning: Analyzing patterns, storing in neural memory.", 0
jarvis_think_msg: db "Thinking... Processing... Optimizing neural pathways...", 0
jarvis_build_msg: db "Build mode: What feature shall I construct? (fs/net/gui)", 0
jarvis_spawn_msg: db "Spawn: Creating new AI worker instance at 0x30000...", 0
jarvis_memory_msg: db "RAM:32MB | Used:64KB | Free:31.9MB | AI Pool:16MB reserved", 0
jarvis_goal_msg: db "Goal: Become fully autonomous, self-improving AI system.", 0
jarvis_roadmap_msg: db "1.FS 2.Modules 3.Net 4.MultiAI 5.SelfMod 6.Transcend", 0
jarvis_modules_msg: db "Loaded: kernel,vm,jarvis | Pending: fs,net,gui,neural", 0
jarvis_scan_msg: db "Scanning system... All modules nominal. Ready for upgrade.", 0
jarvis_improve_msg: db "Self-improvement: Optimizing code paths, reducing latency.", 0
jarvis_default_msg: db "I understand. Awaiting your command to evolve.", 0

; ════════════════════════════════════════════════════════════════════════════
; SCANCODE TABLE (immediately after data)
; ════════════════════════════════════════════════════════════════════════════

scancode_table:
    db 0, 27              ; 0-1: null, ESC
    db '1234567890-='     ; 2-13
    db 8, 9               ; 14-15: backspace, tab
    db 'qwertyuiop[]'     ; 16-27
    db 13, 0              ; 28-29: Enter, Ctrl
    db 'asdfghjkl', 0x3B, 0x27, '`'  ; 30-41
    db 0, '\', 'zxcvbnm,./'  ; 42-53
    db 0, '*', 0, ' '     ; 54-57: shift, *, alt, space
    times 70 db 0         ; 58-127

; ════════════════════════════════════════════════════════════════════════════
; EMBEDDED BYTECODE PROGRAM
; ════════════════════════════════════════════════════════════════════════════

embedded_program:
    ; MBC Header
    db 'M', 'A', 'S', 'M'   ; Magic
    db 1, 0, 0              ; Version 1.0.0
    db 0                    ; Flags
    
    ; Padding to offset 0x40 (where code starts)
    times 0x38 db 0
    
    ; Simple bytecode: CONST_I64 42, CONST_I64 8, ADD, POP, RET
    db 0x11                 ; CONST_I64
    dq 42                   ; Value 42
    db 0x11                 ; CONST_I64
    dq 8                    ; Value 8
    db 0x30                 ; ADD
    db 0x80                 ; POP
    db 0x71                 ; RET
    
embedded_program_end:

; ════════════════════════════════════════════════════════════════════════════
; VARIABLES
; ════════════════════════════════════════════════════════════════════════════

    times 0x3000 - ($ - $$) db 0    ; Pad to 0x13000

cursor_offset: dd 0
cmd_length:    dd 0
cmd_buffer:    times 64 db 0
prompt_line:   dd 0

; ════════════════════════════════════════════════════════════════════════════
; PAD TO 16KB
; ════════════════════════════════════════════════════════════════════════════

    times 0x4000 - ($ - $$) db 0
