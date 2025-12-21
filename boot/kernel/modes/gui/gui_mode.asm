; ============================================================================
; GUI_MODE.ASM - Desktop with Files + Terminal icons
; ============================================================================
; mode_flag=2: Simple desktop interface
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; GUI_MODE - Main desktop mode entry point
; ============================================================================
gui_mode:
    push rbx

    cmp byte [gui_needs_redraw], 1
    je .do_full_redraw

    ; Check if mouse moved
    movzx eax, word [mouse_x]
    cmp ax, [gui_last_mouse_x]
    jne .mouse_moved
    movzx eax, word [mouse_y]
    cmp ax, [gui_last_mouse_y]
    jne .mouse_moved

    call gui_handle_click
    jmp .skip_redraw

.mouse_moved:
    ; Erase old cursor
    movzx edi, word [gui_last_mouse_x]
    movzx esi, word [gui_last_mouse_y]
    mov edx, 12
    mov ecx, 12
    mov r8d, 0x00205080
    call fill_rect

    mov ax, [mouse_x]
    mov [gui_last_mouse_x], ax
    mov ax, [mouse_y]
    mov [gui_last_mouse_y], ax

    call gui_redraw_icons_if_needed
    call gui_draw_cursor
    call gui_handle_click
    jmp .skip_redraw

.do_full_redraw:
    mov byte [gui_needs_redraw], 0

    ; Draw desktop background
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    sub ebx, TASKBAR_H
    imul eax, ebx
    mov ecx, eax
    mov eax, 0x00205080
.desktop_bg:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .desktop_bg

    ; Draw taskbar
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, TASKBAR_H
    imul eax, [screen_pitch]
    add rdi, rax
    mov eax, [screen_width]
    imul eax, TASKBAR_H
    mov ecx, eax
    mov eax, 0x00303030
.taskbar_bg:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .taskbar_bg

    call gui_draw_all_icons
    call gui_handle_click
    call gui_draw_cursor

    mov ax, [mouse_x]
    mov [gui_last_mouse_x], ax
    mov ax, [mouse_y]
    mov [gui_last_mouse_y], ax

.skip_redraw:
    pop rbx
    jmp main_loop

; ============================================================================
; HELPER FUNCTIONS
; ============================================================================
gui_redraw_icons_if_needed:
    movzx eax, word [gui_last_mouse_x]
    movzx ebx, word [gui_last_mouse_y]

    cmp eax, 90
    jg .check_terminal
    cmp eax, 35
    jl .check_terminal
    cmp ebx, 90
    jg .check_terminal
    cmp ebx, 45
    jl .check_terminal
    call gui_draw_files_icon
    ret

.check_terminal:
    cmp eax, 100
    jg .no_redraw
    cmp eax, 35
    jl .no_redraw
    cmp ebx, 150
    jg .no_redraw
    cmp ebx, 105
    jl .no_redraw
    call gui_draw_terminal_icon

.no_redraw:
    ret

gui_draw_all_icons:
    call gui_draw_files_icon
    call gui_draw_terminal_icon
    ret

gui_draw_files_icon:
    mov edi, 50
    mov esi, 50
    mov edx, 0x00FFFF00
    call draw_icon_folder
    mov edi, 45
    mov esi, 70
    lea rdx, [gui_str_files]
    mov ecx, 0x00FFFFFF
    call video_text
    ret

gui_draw_terminal_icon:
    mov edi, 50
    mov esi, 110
    mov edx, 0x00008080
    call draw_icon_terminal
    mov edi, 38
    mov esi, 130
    lea rdx, [gui_str_terminal]
    mov ecx, 0x00FFFFFF
    call video_text
    ret

gui_handle_click:
    test byte [mouse_buttons], 1
    jz .no_click

    cmp byte [gui_click_handled], 1
    je .no_click
    mov byte [gui_click_handled], 1

    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Files icon
    cmp eax, 40
    jl .check_terminal
    cmp eax, 80
    jg .check_terminal
    cmp ebx, 50
    jl .check_terminal
    cmp ebx, 85
    jg .check_terminal
    mov byte [gui_needs_redraw], 1
    mov byte [mode_flag], 4
    jmp .done

.check_terminal:
    cmp eax, 40
    jl .no_click
    cmp eax, 80
    jg .no_click
    cmp ebx, 110
    jl .no_click
    cmp ebx, 145
    jg .no_click
    mov byte [gui_needs_redraw], 1
    mov byte [mode_flag], 1
    jmp .done

.no_click:
    test byte [mouse_buttons], 1
    jnz .done
    mov byte [gui_click_handled], 0
.done:
    ret

gui_draw_cursor:
    push rbx
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    mov edx, 10
    mov ecx, 10
    mov r8d, 0x00FFFFFF
    call fill_rect
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .data
gui_str_files:      db "Files", 0
gui_str_terminal:   db "Terminal", 0
gui_click_handled:  db 0
gui_needs_redraw:   db 1
gui_last_mouse_x:   dw 0
gui_last_mouse_y:   dw 0
gui_widgets_init:   db 0
gui_root_widget:    dq 0
gui_files_btn:      dq 0
gui_term_btn:       dq 0
