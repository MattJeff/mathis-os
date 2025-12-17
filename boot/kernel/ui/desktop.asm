; ============================================================================
; MathisOS - Desktop UI
; ============================================================================
; Elements du bureau : menu start, curseur souris, icones
; - draw_start_menu
; - draw_mouse_cursor
; - draw_icon_terminal, draw_icon_folder, draw_icon_cube
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; DRAW START MENU
; ════════════════════════════════════════════════════════════════════════════
draw_start_menu:
    push rbx

    ; Menu background at y = screen_height - TASKBAR_H - 70
    mov edi, 4
    mov esi, [screen_height]
    sub esi, TASKBAR_H
    sub esi, 70
    mov edx, 80
    mov ecx, 68
    mov r8d, COL_TASKBAR_LT
    call fill_rect

    ; Border
    mov edi, 4
    mov esi, [screen_height]
    sub esi, TASKBAR_H
    sub esi, 70
    mov edx, 80
    mov ecx, 68
    mov r8d, COL_BORDER
    call draw_rect

    ; Menu items - Terminal at (12, taskbar_y - 64)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 64
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12
    mov rsi, str_menu_term
    mov r8d, COL_TEXT
    call draw_text

    ; Files at (12, taskbar_y - 50)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 50
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12
    mov rsi, str_menu_files
    mov r8d, COL_TEXT
    call draw_text

    ; 3D at (12, taskbar_y - 36)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 36
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12
    mov rsi, str_menu_3d
    mov r8d, COL_TEXT
    call draw_text

    ; About at (12, taskbar_y - 22)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 22
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12
    mov rsi, str_menu_about
    mov r8d, COL_TEXT
    call draw_text

    ; Reboot at (12, taskbar_y - 8)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    sub eax, 8
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12
    mov rsi, str_menu_reboot
    mov r8d, COL_CLOSE_BTN
    call draw_text

    pop rbx
    ret
