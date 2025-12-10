; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - MATHIS OS 64-bit Mode with Full Features
; - Timer IRQ0 (scheduler tick)
; - Keyboard IRQ1 (full input)
; - Shell mode + Graphics mode toggle
; - 3D rotating cube
; ════════════════════════════════════════════════════════════════════════════

GFX64_FB    equ 0xA0000
GFX64_W     equ 320
GFX64_H     equ 200
CENTER_X    equ 160
CENTER_Y    equ 100

do_go64:
    cli

    ; Setup page tables at 0x1000 (identity map first 2MB)
    mov edi, 0x1000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    mov dword [0x1000], 0x2003      ; PML4[0] -> PDPT
    mov dword [0x2000], 0x3003      ; PDPT[0] -> PD
    mov dword [0x3000], 0x00000083  ; PD[0] -> 2MB page

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load CR3
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Load GDT
    lgdt [gdt64_ptr]

    ; Enable Paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    jmp 0x08:long_mode_entry

; ════════════════════════════════════════════════════════════════════════════
; 64-BIT LONG MODE
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
long_mode_entry:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Initialize variables
    mov qword [tick_count], 0
    mov byte [mode_flag], 0         ; 0=graphics, 1=shell
    mov byte [key_buffer], 0
    mov byte [cmd_pos], 0
    mov qword [angleX], 0
    xor r12, r12

    ; Clear command buffer
    mov rdi, cmd_buf
    mov rcx, 64
    xor al, al
    rep stosb

    ; Setup IDT
    call setup_idt64

    ; Setup PIC
    call setup_pic64

    ; Setup PIT (100Hz)
    call setup_pit64

    ; Clear keyboard buffer
    in al, 0x60
    in al, 0x60

    ; Enable interrupts
    sti

; ════════════════════════════════════════════════════════════════════════════
; MAIN LOOP
; ════════════════════════════════════════════════════════════════════════════
main_loop:
    ; Check mode
    cmp byte [mode_flag], 1
    je shell_mode

    ; === GRAPHICS MODE ===
graphics_mode:
    ; Clear screen
    mov rdi, GFX64_FB
    mov rcx, GFX64_W * GFX64_H / 8
    xor rax, rax
    rep stosq

    ; Draw tick counter at top
    mov rdi, GFX64_FB + 5
    mov rax, [tick_count]
    call draw_hex

    ; Get rotation angles
    mov rax, r12
    and rax, 0x3F
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r13, byte [sin_table + rax]
    movsx r14, byte [sin_table + rbx]

    mov rax, [angleX]
    and rax, 0x3F
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r8, byte [sin_table + rax]
    movsx r9, byte [sin_table + rbx]

    ; Transform and draw cube (8 vertices, 12 edges)
    ; Vertex 0-7
    mov rdi, -40
    mov rsi, -40
    mov rdx, -40
    call transform_vertex
    mov [v0x], rax
    mov [v0y], rbx

    mov rdi, 40
    mov rsi, -40
    mov rdx, -40
    call transform_vertex
    mov [v1x], rax
    mov [v1y], rbx

    mov rdi, 40
    mov rsi, 40
    mov rdx, -40
    call transform_vertex
    mov [v2x], rax
    mov [v2y], rbx

    mov rdi, -40
    mov rsi, 40
    mov rdx, -40
    call transform_vertex
    mov [v3x], rax
    mov [v3y], rbx

    mov rdi, -40
    mov rsi, -40
    mov rdx, 40
    call transform_vertex
    mov [v4x], rax
    mov [v4y], rbx

    mov rdi, 40
    mov rsi, -40
    mov rdx, 40
    call transform_vertex
    mov [v5x], rax
    mov [v5y], rbx

    mov rdi, 40
    mov rsi, 40
    mov rdx, 40
    call transform_vertex
    mov [v6x], rax
    mov [v6y], rbx

    mov rdi, -40
    mov rsi, 40
    mov rdx, 40
    call transform_vertex
    mov [v7x], rax
    mov [v7y], rbx

    ; Draw edges - Front face (white)
    mov r8, 15
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v1x]
    mov rcx, [v1y]
    call draw_line
    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v2x]
    mov rcx, [v2y]
    call draw_line
    mov rdi, [v2x]
    mov rsi, [v2y]
    mov rdx, [v3x]
    mov rcx, [v3y]
    call draw_line
    mov rdi, [v3x]
    mov rsi, [v3y]
    mov rdx, [v0x]
    mov rcx, [v0y]
    call draw_line

    ; Back face (green)
    mov r8, 10
    mov rdi, [v4x]
    mov rsi, [v4y]
    mov rdx, [v5x]
    mov rcx, [v5y]
    call draw_line
    mov rdi, [v5x]
    mov rsi, [v5y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    call draw_line
    mov rdi, [v6x]
    mov rsi, [v6y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    call draw_line
    mov rdi, [v7x]
    mov rsi, [v7y]
    mov rdx, [v4x]
    mov rcx, [v4y]
    call draw_line

    ; Connecting edges (cyan)
    mov r8, 11
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v4x]
    mov rcx, [v4y]
    call draw_line
    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v5x]
    mov rcx, [v5y]
    call draw_line
    mov rdi, [v2x]
    mov rsi, [v2y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    call draw_line
    mov rdi, [v3x]
    mov rsi, [v3y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    call draw_line

    ; Draw help text at bottom
    mov rdi, GFX64_FB + 320 * 190 + 10
    mov rsi, msg_help_gfx
    mov r8, 7
    call draw_text

    ; Update angles
    inc r12
    inc qword [angleX]

    ; Delay
    mov rcx, 3000000
.delay:
    dec rcx
    jnz .delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; SHELL MODE - Text interface
; ════════════════════════════════════════════════════════════════════════════
shell_mode:
    ; Clear screen (dark blue)
    mov rdi, GFX64_FB
    mov rcx, GFX64_W * GFX64_H
    mov al, 1
    rep stosb

    ; Draw banner
    mov rdi, GFX64_FB + 320 * 10 + 10
    mov rsi, msg_banner
    mov r8, 15
    call draw_text

    ; Draw tick count
    mov rdi, GFX64_FB + 320 * 25 + 10
    mov rsi, msg_ticks
    mov r8, 14
    call draw_text
    mov rdi, GFX64_FB + 320 * 25 + 80
    mov rax, [tick_count]
    call draw_hex

    ; Draw prompt
    mov rdi, GFX64_FB + 320 * 50 + 10
    mov rsi, msg64_prompt
    mov r8, 10
    call draw_text

    ; Draw command buffer
    mov rdi, GFX64_FB + 320 * 50 + 90
    mov rsi, cmd_buf
    mov r8, 15
    call draw_text

    ; Draw cursor
    movzx rax, byte [cmd_pos]
    shl rax, 3                    ; *8 pixels per char
    add rax, 90
    mov rdi, GFX64_FB + 320 * 58 + 10
    add rdi, rax
    mov byte [rdi], 15            ; White cursor

    ; Draw help
    mov rdi, GFX64_FB + 320 * 180 + 10
    mov rsi, msg_help_shell
    mov r8, 7
    call draw_text

    ; Small delay
    mov rcx, 500000
.shell_delay:
    dec rcx
    jnz .shell_delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; DRAW TEXT - Simple text rendering (6 pixels per char)
; rdi = screen pos, rsi = string, r8 = color
; ════════════════════════════════════════════════════════════════════════════
draw_text:
    push rax
    push rcx
    push rdi
.loop:
    lodsb
    test al, al
    jz .done
    ; Draw 6 colored pixels per character
    mov rcx, 6
.char:
    mov byte [rdi], r8b
    inc rdi
    loop .char
    add rdi, 2                    ; Gap between chars
    jmp .loop
.done:
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW HEX - Draw 64-bit value as hex
; rdi = screen pos, rax = value
; ════════════════════════════════════════════════════════════════════════════
draw_hex:
    push rbx
    push rcx
    push rdx
    mov rcx, 16
.loop:
    rol rax, 4
    mov rdx, rax
    and rdx, 0xF
    cmp dl, 10
    jl .digit
    add dl, 7
.digit:
    add dl, '0'
    mov byte [rdi], dl
    inc rdi
    loop .loop
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TRANSFORM VERTEX
; ════════════════════════════════════════════════════════════════════════════
transform_vertex:
    push rcx
    push r10
    push r11

    ; Rotate Y
    mov rax, rdi
    imul rax, r14
    mov rcx, rdx
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    mov r10, rax

    mov rax, rdi
    imul rax, r13
    neg rax
    mov rcx, rdx
    imul rcx, r14
    add rax, rcx
    sar rax, 5
    mov r11, rax

    ; Rotate X
    mov rax, rsi
    imul rax, r9
    mov rcx, r11
    imul rcx, r8
    sub rax, rcx
    sar rax, 5
    mov rbx, rax

    ; Project
    mov rax, r10
    add rax, CENTER_X
    add rbx, CENTER_Y

    pop r11
    pop r10
    pop rcx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW LINE - Bresenham
; ════════════════════════════════════════════════════════════════════════════
draw_line:
    push rbx
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov r9, rdx
    mov r10, rcx
    mov r14, r8

    mov rax, r9
    sub rax, rdi
    mov r11, rax
    test r11, r11
    jns .dx_pos
    neg r11
.dx_pos:

    mov rax, r10
    sub rax, rsi
    mov r12, rax
    test r12, r12
    jns .dy_pos
    neg r12
.dy_pos:
    neg r12

    mov r13, 1
    cmp rdi, r9
    jl .sx_done
    neg r13
.sx_done:

    mov r15, 1
    cmp rsi, r10
    jl .sy_done
    neg r15
.sy_done:

    mov rbx, r11
    add rbx, r12

.line_loop:
    cmp rdi, 0
    jl .skip
    cmp rdi, GFX64_W
    jge .skip
    cmp rsi, 0
    jl .skip
    cmp rsi, GFX64_H
    jge .skip

    push rax
    mov rax, rsi
    imul rax, GFX64_W
    add rax, rdi
    add rax, GFX64_FB
    mov byte [rax], r14b
    pop rax

.skip:
    cmp rdi, r9
    jne .not_done
    cmp rsi, r10
    je .done
.not_done:

    mov rax, rbx
    shl rax, 1

    cmp rax, r12
    jl .skip_x
    add rbx, r12
    add rdi, r13
.skip_x:

    cmp rax, r11
    jg .skip_y
    add rbx, r11
    add rsi, r15
.skip_y:

    jmp .line_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP IDT
; ════════════════════════════════════════════════════════════════════════════
setup_idt64:
    push rax
    push rdi
    push rcx

    ; Clear IDT
    mov rdi, idt64
    mov rcx, 512
    xor rax, rax
    rep stosq

    ; IRQ0 (timer) at 0x20
    mov rdi, idt64 + 0x20 * 16
    mov rax, timer_isr
    call set_idt_entry

    ; IRQ1 (keyboard) at 0x21
    mov rdi, idt64 + 0x21 * 16
    mov rax, keyboard_isr64
    call set_idt_entry

    lidt [idt64_ptr]

    pop rcx
    pop rdi
    pop rax
    ret

set_idt_entry:
    mov word [rdi], ax
    mov word [rdi + 2], 0x08
    mov byte [rdi + 4], 0
    mov byte [rdi + 5], 0x8E
    shr rax, 16
    mov word [rdi + 6], ax
    shr rax, 16
    mov dword [rdi + 8], eax
    mov dword [rdi + 12], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIC
; ════════════════════════════════════════════════════════════════════════════
setup_pic64:
    push rax

    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    mov al, 0xFC          ; Enable IRQ0 + IRQ1
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SETUP PIT (100Hz)
; ════════════════════════════════════════════════════════════════════════════
setup_pit64:
    push rax
    mov al, 0x36
    out 0x43, al
    mov al, 0x9C          ; 11932 = 0x2E9C
    out 0x40, al
    mov al, 0x2E
    out 0x40, al
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TIMER ISR
; ════════════════════════════════════════════════════════════════════════════
timer_isr:
    push rax
    inc qword [tick_count]
    mov al, 0x20
    out 0x20, al
    pop rax
    iretq

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD ISR 64-bit
; ════════════════════════════════════════════════════════════════════════════
keyboard_isr64:
    push rax
    push rbx

    in al, 0x60

    ; Ignore key release
    test al, 0x80
    jnz .done

    ; ESC = reboot
    cmp al, 0x01
    je .reboot

    ; Tab = toggle mode
    cmp al, 0x0F
    jne .not_tab
    xor byte [mode_flag], 1
    jmp .done
.not_tab:

    ; Only process in shell mode
    cmp byte [mode_flag], 1
    jne .done

    ; Backspace
    cmp al, 0x0E
    jne .not_backspace
    cmp byte [cmd_pos], 0
    je .done
    dec byte [cmd_pos]
    movzx rbx, byte [cmd_pos]
    mov byte [cmd_buf + rbx], 0
    jmp .done
.not_backspace:

    ; Enter = execute command
    cmp al, 0x1C
    jne .not_enter
    call execute_command
    jmp .done
.not_enter:

    ; Convert scancode to ASCII
    movzx rbx, al
    cmp bl, 58
    jae .done
    mov al, [scancode_to_ascii + rbx]
    test al, al
    jz .done

    ; Add to buffer
    movzx rbx, byte [cmd_pos]
    cmp bl, 62
    jae .done
    mov [cmd_buf + rbx], al
    inc byte [cmd_pos]

.done:
    mov al, 0x20
    out 0x20, al
    pop rbx
    pop rax
    iretq

.reboot:
    lidt [idt64_null]
    int 0

; ════════════════════════════════════════════════════════════════════════════
; EXECUTE COMMAND
; ════════════════════════════════════════════════════════════════════════════
execute_command:
    push rax
    push rbx
    push rcx

    ; Check "help"
    cmp dword [cmd_buf], 'help'
    je .cmd_help

    ; Check "clear"
    cmp dword [cmd_buf], 'clea'
    je .cmd_clear

    ; Check "tick"
    cmp dword [cmd_buf], 'tick'
    je .cmd_tick

    jmp .clear_cmd

.cmd_help:
.cmd_clear:
.cmd_tick:
    ; Just clear for now
.clear_cmd:
    ; Clear command buffer
    mov rdi, cmd_buf
    mov rcx, 64
    xor al, al
    rep stosb
    mov byte [cmd_pos], 0

    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
align 8
tick_count:     dq 0
angleX:         dq 0
mode_flag:      db 0
key_buffer:     db 0
cmd_pos:        db 0
cmd_buf:        times 64 db 0

; Vertex storage
v0x: dq 0
v0y: dq 0
v1x: dq 0
v1y: dq 0
v2x: dq 0
v2y: dq 0
v3x: dq 0
v3y: dq 0
v4x: dq 0
v4y: dq 0
v5x: dq 0
v5y: dq 0
v6x: dq 0
v6y: dq 0
v7x: dq 0
v7y: dq 0

; Messages
msg_banner:     db "MATHIS OS 64-BIT", 0
msg_ticks:      db "Ticks:", 0
msg64_prompt:   db "mathis> ", 0
msg_help_gfx:   db "TAB=shell ESC=reboot", 0
msg_help_shell: db "TAB=graphics ESC=reboot", 0

; Scancode to ASCII table
scancode_to_ascii:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '

; Sin table
align 8
sin_table:
    db  0,  3,  6,  9, 12, 15, 18, 21
    db 24, 26, 28, 30, 31, 32, 32, 32
    db 32, 32, 32, 31, 30, 28, 26, 24
    db 21, 18, 15, 12,  9,  6,  3,  0
    db  0, -3, -6, -9,-12,-15,-18,-21
    db -24,-26,-28,-30,-31,-32,-32,-32
    db -32,-32,-32,-31,-30,-28,-26,-24
    db -21,-18,-15,-12, -9, -6, -3,  0

; IDT
align 16
idt64:
    times 256 dq 0, 0

idt64_ptr:
    dw 256*16 - 1
    dq idt64

idt64_null:
    dw 0
    dq 0

[BITS 32]
; GDT
align 16
gdt64:
    dq 0
    dq 0x00209A0000000000
    dq 0x0000920000000000
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64
