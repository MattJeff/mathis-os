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
    jl .check_fs
    cmp dword [cmd_buffer], 'jarv'
    jne .check_fs
    cmp word [cmd_buffer+4], 'is'
    jne .check_fs
    jmp .do_jarvis

.check_fs:
    ; Check if command starts with "fs " (3 chars)
    cmp dword [cmd_length], 2
    jl .unknown
    cmp word [cmd_buffer], 'fs'
    jne .unknown
    jmp .do_fs
    
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

.do_fs:
    ; Filesystem commands: fs list, fs read, fs write, fs init
    inc dword [prompt_line]
    mov esi, fs_prompt
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0B        ; Cyan
    call print_string
    
    ; Check subcommand at cmd_buffer+3
    cmp dword [cmd_buffer+3], 'list'
    je .fs_list
    cmp dword [cmd_buffer+3], 'init'
    je .fs_init
    cmp dword [cmd_buffer+3], 'info'
    je .fs_info
    cmp dword [cmd_buffer+3], 'help'
    je .fs_help
    cmp dword [cmd_buffer+3], 'make'
    je .fs_make
    cmp dword [cmd_buffer+3], 'read'
    je .fs_read
    cmp dword [cmd_buffer+3], 'cat '
    je .fs_read
    jmp .fs_help

.fs_list:
    inc dword [prompt_line]
    mov esi, fs_list_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.fs_init:
    ; Initialize RAM disk at 0x30000
    call fs_initialize
    inc dword [prompt_line]
    mov esi, fs_init_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green
    call print_string
    jmp .new_prompt

.fs_info:
    inc dword [prompt_line]
    mov esi, fs_info_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.fs_help:
    inc dword [prompt_line]
    mov esi, fs_help_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    jmp .new_prompt

.fs_make:
    ; Create a demo file: "fs make" creates test.txt
    call fs_create_demo_file
    inc dword [prompt_line]
    mov esi, fs_make_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A        ; Green
    call print_string
    jmp .new_prompt

.fs_read:
    ; Read first file and display content
    call fs_read_first_file
    inc dword [prompt_line]
    mov esi, FS_DATA    ; Display file content from RAM disk
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0F        ; White
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
; Supported Opcodes (60+ total):
; Control:     0x00 NOP, 0x01 HALT, 0x02 PANIC
; Constants:   0x10 CONST, 0x11 CONST_NONE, 0x12 CONST_TRUE, 0x13 CONST_FALSE
;              0x14 CONST_I64, 0x15 CONST_F64, 0x16 CONST_STR, 0x17 CONST_SMALL
; Variables:   0x20 GET_LOCAL, 0x21 SET_LOCAL, 0x22 GET_GLOBAL, 0x23 SET_GLOBAL
; Arithmetic:  0x30 ADD, 0x31 SUB, 0x32 MUL, 0x33 DIV, 0x34 MOD, 0x35 NEG
; Comparison:  0x40 EQ, 0x41 NE, 0x42 LT, 0x43 LE, 0x44 GT, 0x45 GE
; Logic:       0x50 AND, 0x51 OR, 0x52 NOT, 0x53 BIT_AND, 0x54 BIT_OR
;              0x55 BIT_XOR, 0x56 BIT_NOT, 0x57 SHL, 0x58 SHR
; Control:     0x60 JUMP, 0x61 JUMP_IF_TRUE, 0x62 JUMP_IF_FALSE, 0x65 CALL
;              0x68 RET, 0x69 THROW
; Stack:       0x70 POP, 0x71 DUP, 0x72 DUP2, 0x73 SWAP, 0x74 ROT, 0x75 OVER
; Objects:     0x80 GET_FIELD, 0x81 SET_FIELD, 0x84 MAKE_STRUCT
; Collections: 0x90 MAKE_LIST, 0x93 INDEX, 0x94 INDEX_SET, 0x95 LEN, 0x96 PUSH
; AI:          0xA0 AI_BREAK, 0xA1 AI_CALL, 0xA2 AI_DECIDE, 0xA3 AI_LEARN
; System:      0xC0 SYSCALL, 0xC1 ALLOC, 0xC2 FREE, 0xC3 PRINT, 0xC4 READ
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
    
    ; Dispatch opcode - 60+ opcodes
    ; Control (0x00-0x0F)
    cmp al, 0x00
    je .op_nop
    cmp al, 0x01
    je .op_halt
    cmp al, 0x02
    je .op_panic
    
    ; Constants (0x10-0x1F)
    cmp al, 0x10
    je .op_const
    cmp al, 0x11
    je .op_const_none
    cmp al, 0x12
    je .op_const_true
    cmp al, 0x13
    je .op_const_false
    cmp al, 0x14
    je .op_const_i64
    cmp al, 0x15
    je .op_const_f64
    cmp al, 0x16
    je .op_const_str
    cmp al, 0x17
    je .op_const_small
    
    ; Variables (0x20-0x2F)
    cmp al, 0x20
    je .op_get_local
    cmp al, 0x21
    je .op_set_local
    cmp al, 0x22
    je .op_get_global
    cmp al, 0x23
    je .op_set_global
    
    ; Arithmetic (0x30-0x3F)
    cmp al, 0x30
    je .op_add
    cmp al, 0x31
    je .op_sub
    cmp al, 0x32
    je .op_mul
    cmp al, 0x33
    je .op_div
    cmp al, 0x34
    je .op_mod
    cmp al, 0x35
    je .op_neg
    
    ; Comparison (0x40-0x4F)
    cmp al, 0x40
    je .op_eq
    cmp al, 0x41
    je .op_ne
    cmp al, 0x42
    je .op_lt
    cmp al, 0x43
    je .op_le
    cmp al, 0x44
    je .op_gt
    cmp al, 0x45
    je .op_ge
    
    ; Logic (0x50-0x5F)
    cmp al, 0x50
    je .op_and
    cmp al, 0x51
    je .op_or
    cmp al, 0x52
    je .op_not
    cmp al, 0x53
    je .op_bit_and
    cmp al, 0x54
    je .op_bit_or
    cmp al, 0x55
    je .op_bit_xor
    cmp al, 0x56
    je .op_bit_not
    cmp al, 0x57
    je .op_shl
    cmp al, 0x58
    je .op_shr
    
    ; Control Flow (0x60-0x6F)
    cmp al, 0x60
    je .op_jump
    cmp al, 0x61
    je .op_jump_if_true
    cmp al, 0x62
    je .op_jump_if_false
    cmp al, 0x65
    je .op_call
    cmp al, 0x68
    je .op_ret
    
    ; Stack (0x70-0x7F)
    cmp al, 0x70
    je .op_pop
    cmp al, 0x71
    je .op_dup
    cmp al, 0x72
    je .op_dup2
    cmp al, 0x73
    je .op_swap
    cmp al, 0x74
    je .op_rot
    cmp al, 0x75
    je .op_over
    
    ; Objects (0x80-0x8F)
    cmp al, 0x80
    je .op_get_field
    cmp al, 0x81
    je .op_set_field
    cmp al, 0x84
    je .op_make_struct
    
    ; Collections (0x90-0x9F)
    cmp al, 0x90
    je .op_make_list
    cmp al, 0x93
    je .op_index
    cmp al, 0x94
    je .op_index_set
    cmp al, 0x95
    je .op_len
    cmp al, 0x96
    je .op_push_list
    
    ; AI (0xA0-0xAF)
    cmp al, 0xA0
    je .op_ai_break
    cmp al, 0xA1
    je .op_ai_call
    cmp al, 0xA2
    je .op_ai_decide
    cmp al, 0xA3
    je .op_ai_learn
    
    ; System (0xC0-0xCF)
    cmp al, 0xC0
    je .op_syscall
    cmp al, 0xC1
    je .op_alloc
    cmp al, 0xC2
    je .op_free
    cmp al, 0xC3
    je .op_print
    cmp al, 0xC4
    je .op_read
    
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

.op_get_local:
    ; Read local index (1 byte)
    movzx eax, byte [esi]
    inc esi
    ; Get value from locals area (simplified: use fixed offset)
    mov ebx, [0x24000 + eax*4]
    sub ebp, 4
    mov [ebp], ebx
    jmp .vm_loop

.op_set_local:
    ; Read local index (1 byte)
    movzx eax, byte [esi]
    inc esi
    ; Pop value and store in locals
    mov ebx, [ebp]
    add ebp, 4
    mov [0x24000 + eax*4], ebx
    jmp .vm_loop

.op_mul:
    ; Pop two values, multiply, push result
    mov eax, [ebp]
    add ebp, 4
    imul eax, [ebp]
    mov [ebp], eax
    jmp .vm_loop

.op_div:
    ; Pop two values, divide, push result
    mov eax, [ebp+4]        ; dividend
    cdq
    mov ebx, [ebp]          ; divisor
    add ebp, 4
    idiv ebx
    mov [ebp], eax
    jmp .vm_loop

.op_eq:
    ; Pop two values, compare, push 1 if equal
    mov eax, [ebp]
    add ebp, 4
    cmp eax, [ebp]
    je .eq_true
    mov dword [ebp], 0
    jmp .vm_loop
.eq_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_lt:
    ; Pop two values, push 1 if a < b
    mov eax, [ebp]          ; b
    add ebp, 4
    cmp [ebp], eax          ; a < b?
    jl .lt_true
    mov dword [ebp], 0
    jmp .vm_loop
.lt_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_gt:
    ; Pop two values, push 1 if a > b
    mov eax, [ebp]          ; b
    add ebp, 4
    cmp [ebp], eax          ; a > b?
    jg .gt_true
    mov dword [ebp], 0
    jmp .vm_loop
.gt_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_and:
    ; Pop two values, push logical AND
    mov eax, [ebp]
    add ebp, 4
    and eax, [ebp]
    mov [ebp], eax
    jmp .vm_loop

.op_or:
    ; Pop two values, push logical OR
    mov eax, [ebp]
    add ebp, 4
    or eax, [ebp]
    mov [ebp], eax
    jmp .vm_loop

.op_not:
    ; Pop value, push logical NOT
    mov eax, [ebp]
    test eax, eax
    jz .not_true
    mov dword [ebp], 0
    jmp .vm_loop
.not_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_jump:
    ; Read jump offset (2 bytes)
    movzx eax, word [esi]
    ; Set IP to new offset (relative to bytecode base)
    mov esi, 0x20040        ; Base + header
    add esi, eax
    jmp .vm_loop

.op_jump_if:
    ; Read jump offset (2 bytes)
    movzx eax, word [esi]
    add esi, 2
    ; Pop condition
    mov ebx, [ebp]
    add ebp, 4
    test ebx, ebx
    jz .vm_loop             ; Don't jump if false
    ; Jump
    mov esi, 0x20040
    add esi, eax
    jmp .vm_loop

.op_call:
    ; Read function offset (2 bytes)
    movzx eax, word [esi]
    add esi, 2
    ; Push return address
    sub ebp, 4
    mov [ebp], esi
    ; Jump to function
    mov esi, 0x20040
    add esi, eax
    jmp .vm_loop

.op_dup:
    ; Duplicate top of stack
    mov eax, [ebp]
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

; === NEW OPCODES ===

.op_halt:
    jmp .vm_done

.op_panic:
    jmp .vm_error

.op_const_none:
    sub ebp, 4
    mov dword [ebp], 0
    jmp .vm_loop

.op_const_true:
    sub ebp, 4
    mov dword [ebp], 1
    jmp .vm_loop

.op_const_false:
    sub ebp, 4
    mov dword [ebp], 0
    jmp .vm_loop

.op_const_f64:
    mov eax, [esi]
    add esi, 8
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_const_str:
    movzx eax, word [esi]
    add esi, 2
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_const_small:
    movsx eax, byte [esi]
    inc esi
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_get_global:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [0x23000 + eax*4]
    sub ebp, 4
    mov [ebp], ebx
    jmp .vm_loop

.op_set_global:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [ebp]
    add ebp, 4
    mov [0x23000 + eax*4], ebx
    jmp .vm_loop

.op_mod:
    mov eax, [ebp+4]
    cdq
    mov ebx, [ebp]
    add ebp, 4
    idiv ebx
    mov [ebp], edx      ; remainder
    jmp .vm_loop

.op_neg:
    neg dword [ebp]
    jmp .vm_loop

.op_ne:
    mov eax, [ebp]
    add ebp, 4
    cmp eax, [ebp]
    jne .ne_true
    mov dword [ebp], 0
    jmp .vm_loop
.ne_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_le:
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    jle .le_true
    mov dword [ebp], 0
    jmp .vm_loop
.le_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_ge:
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    jge .ge_true
    mov dword [ebp], 0
    jmp .vm_loop
.ge_true:
    mov dword [ebp], 1
    jmp .vm_loop

.op_bit_and:
    mov eax, [ebp]
    add ebp, 4
    and [ebp], eax
    jmp .vm_loop

.op_bit_or:
    mov eax, [ebp]
    add ebp, 4
    or [ebp], eax
    jmp .vm_loop

.op_bit_xor:
    mov eax, [ebp]
    add ebp, 4
    xor [ebp], eax
    jmp .vm_loop

.op_bit_not:
    not dword [ebp]
    jmp .vm_loop

.op_shl:
    mov ecx, [ebp]
    add ebp, 4
    shl dword [ebp], cl
    jmp .vm_loop

.op_shr:
    mov ecx, [ebp]
    add ebp, 4
    sar dword [ebp], cl
    jmp .vm_loop

.op_jump_if_true:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [ebp]
    add ebp, 4
    test ebx, ebx
    jz .vm_loop
    mov esi, 0x20040
    add esi, eax
    jmp .vm_loop

.op_jump_if_false:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [ebp]
    add ebp, 4
    test ebx, ebx
    jnz .vm_loop
    mov esi, 0x20040
    add esi, eax
    jmp .vm_loop

.op_dup2:
    mov eax, [ebp]
    mov ebx, [ebp+4]
    sub ebp, 8
    mov [ebp], eax
    mov [ebp+4], ebx
    jmp .vm_loop

.op_swap:
    mov eax, [ebp]
    mov ebx, [ebp+4]
    mov [ebp], ebx
    mov [ebp+4], eax
    jmp .vm_loop

.op_rot:
    mov eax, [ebp]
    mov ebx, [ebp+4]
    mov ecx, [ebp+8]
    mov [ebp], ebx
    mov [ebp+4], ecx
    mov [ebp+8], eax
    jmp .vm_loop

.op_over:
    mov eax, [ebp+4]
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_get_field:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [ebp]          ; object ptr
    mov ecx, [ebx + eax*4]  ; field value
    mov [ebp], ecx
    jmp .vm_loop

.op_set_field:
    movzx eax, word [esi]
    add esi, 2
    mov ebx, [ebp+4]        ; object ptr
    mov ecx, [ebp]          ; value
    add ebp, 4
    mov [ebx + eax*4], ecx
    jmp .vm_loop

.op_make_struct:
    movzx eax, word [esi]   ; type_id
    add esi, 2
    movzx ebx, byte [esi]   ; field count
    inc esi
    ; Allocate at heap (simplified: use fixed area)
    mov edi, [heap_ptr]
    mov ecx, ebx
.make_struct_loop:
    test ecx, ecx
    jz .make_struct_done
    mov eax, [ebp]
    add ebp, 4
    mov [edi], eax
    add edi, 4
    dec ecx
    jmp .make_struct_loop
.make_struct_done:
    mov eax, [heap_ptr]
    sub ebp, 4
    mov [ebp], eax
    mov [heap_ptr], edi
    jmp .vm_loop

.op_make_list:
    movzx ebx, word [esi]   ; count
    add esi, 2
    mov edi, [heap_ptr]
    mov [edi], ebx          ; store length
    add edi, 4
    mov ecx, ebx
.make_list_loop:
    test ecx, ecx
    jz .make_list_done
    mov eax, [ebp]
    add ebp, 4
    mov [edi], eax
    add edi, 4
    dec ecx
    jmp .make_list_loop
.make_list_done:
    mov eax, [heap_ptr]
    add dword [heap_ptr], 4
    imul ebx, 4
    add [heap_ptr], ebx
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_index:
    mov eax, [ebp]          ; index
    add ebp, 4
    mov ebx, [ebp]          ; list ptr
    mov ecx, [ebx + 4 + eax*4]
    mov [ebp], ecx
    jmp .vm_loop

.op_index_set:
    mov eax, [ebp+4]        ; index
    mov ebx, [ebp+8]        ; list ptr
    mov ecx, [ebp]          ; value
    add ebp, 8
    mov [ebx + 4 + eax*4], ecx
    jmp .vm_loop

.op_len:
    mov eax, [ebp]          ; list ptr
    mov ebx, [eax]          ; length
    mov [ebp], ebx
    jmp .vm_loop

.op_push_list:
    mov eax, [ebp]          ; value
    mov ebx, [ebp+4]        ; list ptr
    add ebp, 4
    mov ecx, [ebx]          ; length
    mov [ebx + 4 + ecx*4], eax
    inc dword [ebx]
    jmp .vm_loop

; AI Opcodes
.op_ai_break:
    ; AI breakpoint - pause for inspection
    jmp .vm_loop

.op_ai_call:
    ; AI function call
    movzx eax, word [esi]
    add esi, 2
    ; Store AI call ID
    mov [ai_last_call], eax
    jmp .vm_loop

.op_ai_decide:
    ; AI decision - push 1 (always yes for now)
    sub ebp, 4
    mov dword [ebp], 1
    jmp .vm_loop

.op_ai_learn:
    ; AI learn - store pattern
    mov eax, [ebp]
    add ebp, 4
    mov [ai_last_pattern], eax
    jmp .vm_loop

; System Opcodes
.op_alloc:
    mov eax, [ebp]          ; size
    mov ebx, [heap_ptr]
    mov [ebp], ebx          ; return ptr
    add [heap_ptr], eax
    jmp .vm_loop

.op_free:
    add ebp, 4              ; simplified: just pop
    jmp .vm_loop

.op_print:
    mov eax, [ebp]
    add ebp, 4
    inc dword [prompt_line]
    mov esi, vm_output_msg
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0E
    call print_string
    mov esi, 0x20040
    jmp .vm_loop

.op_read:
    ; Read input (simplified: push 0)
    sub ebp, 4
    mov dword [ebp], 0
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
; FILESYSTEM - RAM Disk at 0x30000 (64KB)
; ════════════════════════════════════════════════════════════════════════════
; Structure:
;   0x30000: Header (512 bytes)
;     - Magic: "MTHSFS" (6 bytes)
;     - Version: 1 (2 bytes)  
;     - File count: u16
;     - Total size: u32
;   0x30200: Directory entries (64 bytes each, max 32 files)
;   0x30A00: Data blocks (512 bytes each)

FS_BASE     equ 0x30000
FS_DIR      equ 0x30200
FS_DATA     equ 0x30A00
FS_MAX_FILES equ 32

fs_initialize:
    push eax
    push ecx
    push edi
    
    ; Clear filesystem area (64KB)
    mov edi, FS_BASE
    mov ecx, 16384          ; 64KB / 4 = 16384 dwords
    xor eax, eax
    rep stosd
    
    ; Write magic header "MTHSFS"
    mov edi, FS_BASE
    mov byte [edi], 'M'
    mov byte [edi+1], 'T'
    mov byte [edi+2], 'H'
    mov byte [edi+3], 'S'
    mov byte [edi+4], 'F'
    mov byte [edi+5], 'S'
    
    ; Version 1.0
    mov word [edi+6], 0x0001
    
    ; File count = 0
    mov word [edi+8], 0
    
    ; Total size = 64KB
    mov dword [edi+10], 65536
    
    ; Mark filesystem as initialized
    mov byte [fs_initialized], 1
    
    pop edi
    pop ecx
    pop eax
    ret

fs_initialized: db 0

; VM Heap and AI state
heap_ptr: dd 0x40000            ; Heap starts at 256KB
ai_last_call: dd 0
ai_last_pattern: dd 0

fs_create_demo_file:
    ; Create a demo file in RAM disk
    push eax
    push ecx
    push esi
    push edi
    
    ; Write directory entry at FS_DIR (0x30200)
    mov edi, FS_DIR
    
    ; Filename: "hello.txt"
    mov byte [edi], 'h'
    mov byte [edi+1], 'e'
    mov byte [edi+2], 'l'
    mov byte [edi+3], 'l'
    mov byte [edi+4], 'o'
    mov byte [edi+5], '.'
    mov byte [edi+6], 't'
    mov byte [edi+7], 'x'
    mov byte [edi+8], 't'
    mov byte [edi+9], 0
    
    ; Type = 0 (file)
    mov byte [edi+32], 0
    ; Size = 32
    mov dword [edi+36], 32
    
    ; Write file content at FS_DATA (0x30A00)
    mov edi, FS_DATA
    mov esi, demo_file_content
    mov ecx, 32
.copy_content:
    lodsb
    stosb
    loop .copy_content
    
    ; Increment file count
    mov edi, FS_BASE
    inc word [edi+8]
    
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

fs_read_first_file:
    ; Just return - content is already at FS_DATA
    ret

demo_file_content: db "Hello from MATHIS OS!", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; ════════════════════════════════════════════════════════════════════════════
; IDT
; ════════════════════════════════════════════════════════════════════════════

    times 0x3000 - ($ - $$) db 0    ; Pad to 0x13000 (larger kernel with 60+ opcodes)

idt_ptr:
    dw 256*8 - 1
    dd 0x13006                      ; Address of IDT (0x10000 + 0x3006)

idt:
    times 0x21 dq 0                 ; Entries 0-0x20
    ; Entry 0x21 - Keyboard
    ; keyboard_isr is at offset 0x200 in the kernel, so 0x10000 + 0x200 = 0x10200
    dw 0x0200                       ; Offset low
    dw 0x08                         ; Selector
    db 0
    db 0x8E                         ; Present, Ring 0, 32-bit interrupt gate
    dw 0x0001                       ; Offset high
    times (256-0x22) dq 0           ; Rest of IDT

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════

    times 0x4000 - ($ - $$) db 0    ; Pad to 0x14000

banner_line1: db " __  __    _  _____ _   _ ___ ____     ___  ____  ", 0
banner_line2: db "|  \/  |  / \|_   _| | | |_ _/ ___|   / _ \/ ___| ", 0
banner_line3: db "| |\/| | / _ \ | | | |_| || |\___ \  | | | \___ \ ", 0
banner_line4: db "| |  | |/ ___ \| | |  _  || | ___) | | |_| |___) |", 0
banner_line5: db "|_|  |_/_/   \_\_| |_| |_|___|____/   \___/|____/ ", 0
banner_line6: db "                                            v2.1  ", 0

info_msg:     db "AI-First Operating System - Type 'help' for commands", 0
prompt_msg:   db "> ", 0
help_msg:     db "Commands: help, clear, reboot, run, jarvis, fs", 0
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

; Filesystem messages
fs_prompt: db "FS> ", 0
fs_help_msg: db "fs: init, list, info, make (create file), read (show)", 0
fs_init_msg: db "Filesystem initialized at 0x30000 (64KB RAM disk)", 0
fs_list_msg: db "Files: (use 'fs make' to create, 'fs read' to view)", 0
fs_info_msg: db "MTHSFS v1.0 | Base:0x30000 | Size:64KB | Max:32 files", 0
fs_make_msg: db "Created: hello.txt (32 bytes) - Use 'fs read' to view", 0

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

    times 0x5000 - ($ - $$) db 0    ; Pad to 0x15000

cursor_offset: dd 0
cmd_length:    dd 0
cmd_buffer:    times 64 db 0
prompt_line:   dd 0

; ════════════════════════════════════════════════════════════════════════════
; PAD TO 24KB (larger kernel with 60+ opcodes)
; ════════════════════════════════════════════════════════════════════════════

    times 0x6000 - ($ - $$) db 0
