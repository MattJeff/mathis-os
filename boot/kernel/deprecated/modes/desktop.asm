; ════════════════════════════════════════════════════════════════════════════
; DESKTOP.ASM - Desktop GUI Mode (mode_flag = 2)
; ════════════════════════════════════════════════════════════════════════════
; Features:
;   - Desktop background
;   - Icons (Terminal, Files, 3D Demo)
;   - Taskbar with Start button and clock
;   - Mouse cursor
;   - Window management
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; GUI MODE - Desktop Environment
; ════════════════════════════════════════════════════════════════════════════
gui_mode:
    ; === Draw Desktop Background (32-bit BGRA: teal/cyan color) ===
    push rbx
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    sub ebx, TASKBAR_H
    imul eax, ebx               ; EAX = total pixels (minus taskbar)
    mov ecx, eax                ; ECX = number of pixels
    mov eax, 0x00205080         ; BGRA: B=0x80, G=0x50, R=0x20, A=0x00
.gui_clear_loop:
    mov dword [rdi], eax        ; Write 4 bytes at once (32-bit pixel)
    add rdi, 4
    dec ecx
    jnz .gui_clear_loop
    pop rbx

    ; DEBUG: After clear, just loop back (skip all other drawing)
    jmp main_loop

    ; === Draw Desktop Icons ===
    ; Terminal icon (x=50, y=30)
    mov edi, 50
    mov esi, 30
    mov edx, COL_CYAN
    call draw_icon_terminal
    ; Text at (38, 50)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 50
    add rdi, rax
    add rdi, 38
    mov rsi, str_terminal
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Files icon (x=50, y=80)
    mov edi, 50
    mov esi, 80
    mov edx, COL_YELLOW
    call draw_icon_folder
    ; Text at (45, 100)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 100
    add rdi, rax
    add rdi, 45
    mov rsi, str_files
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; 3D Demo icon (x=50, y=130)
    mov edi, 50
    mov esi, 130
    mov edx, COL_GREEN
    call draw_icon_cube
    ; Text at (38, 150)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 150
    add rdi, rax
    add rdi, 38
    mov rsi, str_3ddemo
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; === Draw Taskbar (32-bit BGRA) ===
    push rbx
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    imul eax, [screen_pitch]
    add rdi, rax
    ; Calculate pixels: screen_width * TASKBAR_H
    mov eax, [screen_width]
    imul eax, TASKBAR_H
    mov ecx, eax
    mov eax, 0x00303030         ; BGRA: dark gray
.taskbar_fill_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .taskbar_fill_loop

    ; Taskbar top highlight
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    imul eax, [screen_pitch]
    add rdi, rax
    mov ecx, [screen_width]
    mov eax, 0x00606060         ; BGRA: light gray
.taskbar_highlight_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .taskbar_highlight_loop
    pop rbx

    ; Start button
    mov edi, 4
    mov esi, [screen_height]
    sub esi, TASKBAR_H
    add esi, 2
    mov edx, 40
    mov ecx, 10
    mov r8d, COL_TASKBAR_LT
    call fill_rect
    ; "Start" text
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    add eax, 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 8
    mov rsi, str_start
    mov r8d, COL_TEXT
    call draw_text

    ; Process indicator
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    add eax, 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 55
    call draw_proc_indicator

    ; Clock (right side)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    add eax, 4
    imul eax, [screen_pitch]
    add rdi, rax
    mov ebx, [screen_width]
    sub ebx, 45
    add rdi, rbx
    call draw_clock

    ; === Draw Start Menu if open ===
    cmp byte [start_menu_open], 1
    jne .no_start_menu
    call draw_start_menu
.no_start_menu:

    ; === Draw Mouse Cursor ===
    call draw_mouse_cursor

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; DRAW 3D WINDOW CONTENT (Mini rotating cube)
; ════════════════════════════════════════════════════════════════════════════
draw_3d_window:
    push rbx
    push r12
    push r13
    push r14
    push r15

    movzx r13, word [rbx + 2]       ; window x
    movzx r14, word [rbx + 4]       ; window y

    ; Mini cube center
    mov r15d, r13d
    add r15d, 60                    ; center x in window

    ; Get rotation angle from tick
    mov rax, [tick_count]
    shr rax, 2
    and rax, 0x3F
    movsx r8, byte [sin_table + rax]
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r9, byte [sin_table + rbx]

    ; Draw simple rotating square (2D projection)
    ; Point 1
    mov rax, -15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x1], eax
    mov rax, -15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, 40
    mov [temp_y1], eax

    ; Point 2
    mov rax, 15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x2], eax
    mov rax, -15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, 40
    mov [temp_y2], eax

    ; Point 3
    mov rax, 15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x3], eax
    mov rax, 15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, 40
    mov [temp_y3], eax

    ; Point 4
    mov rax, -15
    imul rax, r9
    sar rax, 5
    add eax, r15d
    mov [temp_x4], eax
    mov rax, 15
    imul rax, r8
    sar rax, 5
    add eax, r14d
    add eax, 40
    mov [temp_y4], eax

    ; Draw the 4 lines
    mov r8d, COL_GREEN
    mov edi, [temp_x1]
    mov esi, [temp_y1]
    mov edx, [temp_x2]
    mov ecx, [temp_y2]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x2]
    mov esi, [temp_y2]
    mov edx, [temp_x3]
    mov ecx, [temp_y3]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x3]
    mov esi, [temp_y3]
    mov edx, [temp_x4]
    mov ecx, [temp_y4]
    call draw_line

    mov r8d, COL_GREEN
    mov edi, [temp_x4]
    mov esi, [temp_y4]
    mov edx, [temp_x1]
    mov ecx, [temp_y1]
    call draw_line

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
