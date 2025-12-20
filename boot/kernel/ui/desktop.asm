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

; ════════════════════════════════════════════════════════════════════════════
; DRAW MOUSE CURSOR (32-bit BGRA)
; ════════════════════════════════════════════════════════════════════════════
CURSOR_WHITE    equ 0x00FFFFFF
CURSOR_BLACK    equ 0x00000000

draw_mouse_cursor:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Get pitch (zero-extend to 64-bit)
    xor ecx, ecx
    mov ecx, [screen_pitch]              ; pitch in bytes (32-bit, zero-extended)

    ; Calculate framebuffer position: y * pitch + x * 4
    movzx eax, word [mouse_y]
    imul eax, ecx
    movzx ebx, word [mouse_x]
    shl ebx, 2                           ; x * 4 (32-bit pixels)
    add eax, ebx

    ; rdi = framebuffer + offset
    mov rdi, [screen_fb]
    mov edx, eax                         ; zero-extend eax to rdx
    add rdi, rdx

    ; Row 0: X
    mov dword [rdi], CURSOR_WHITE
    add rdi, rcx

    ; Row 1: XX
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_WHITE
    add rdi, rcx

    ; Row 2: X.X
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_BLACK
    mov dword [rdi + 8], CURSOR_WHITE
    add rdi, rcx

    ; Row 3: X..X
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_BLACK
    mov dword [rdi + 8], CURSOR_BLACK
    mov dword [rdi + 12], CURSOR_WHITE
    add rdi, rcx

    ; Row 4: X...X
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_BLACK
    mov dword [rdi + 8], CURSOR_BLACK
    mov dword [rdi + 12], CURSOR_BLACK
    mov dword [rdi + 16], CURSOR_WHITE
    add rdi, rcx

    ; Row 5: X..X
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_BLACK
    mov dword [rdi + 8], CURSOR_BLACK
    mov dword [rdi + 12], CURSOR_WHITE
    add rdi, rcx

    ; Row 6: X.X
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_BLACK
    mov dword [rdi + 8], CURSOR_WHITE
    add rdi, rcx

    ; Row 7: XX
    mov dword [rdi], CURSOR_WHITE
    mov dword [rdi + 4], CURSOR_WHITE

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW ICONS
; ════════════════════════════════════════════════════════════════════════════
draw_icon_terminal:
    ; Terminal icon: rectangle with lines (32-bit)
    push rax
    push rbx
    push rdi
    push rcx

    ; Background
    push rdx
    mov r8d, edx
    mov edx, 16
    mov ecx, 16
    call fill_rect
    pop rdx

    ; Border
    mov r8d, COL_BORDER
    mov edx, 16
    mov ecx, 16
    call draw_rect

    ; Lines inside (text simulation) - 32-bit pixels
    ; Calculate position: (y+3) * pitch + (x+3) * 4
    mov eax, esi
    add eax, 3                      ; y + 3
    imul eax, [screen_pitch]
    mov ebx, edi
    add ebx, 3                      ; x + 3
    shl ebx, 2                      ; * 4 for 32-bit
    add eax, ebx
    mov rbx, [screen_fb]
    add rax, rbx
    ; Draw 5 white pixels on first line
    mov ecx, 0x00FFFFFF             ; White color (BGRA)
    mov dword [rax], ecx
    mov dword [rax + 4], ecx
    mov dword [rax + 8], ecx
    mov dword [rax + 12], ecx
    mov dword [rax + 16], ecx
    ; Move down 3 rows and draw 3 more pixels
    mov ebx, [screen_pitch]
    imul ebx, 3
    add rax, rbx
    mov dword [rax], ecx
    mov dword [rax + 4], ecx
    mov dword [rax + 8], ecx

    pop rcx
    pop rdi
    pop rbx
    pop rax
    ret

draw_icon_folder:
    ; Folder icon
    push rax
    push rbx
    push rdi
    push rsi

    ; Tab part
    mov r8d, edx
    push rdx
    mov edx, 8
    mov ecx, 4
    call fill_rect
    pop rdx

    ; Main folder body
    push rdi
    push rsi
    add esi, 4
    mov r8d, edx
    mov edx, 16
    mov ecx, 12
    call fill_rect
    pop rsi
    pop rdi

    ; Border
    mov r8d, COL_BORDER
    add esi, 4
    mov edx, 16
    mov ecx, 12
    call draw_rect

    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

draw_icon_cube:
    ; 3D cube icon
    push rax
    push rdi
    push rsi

    ; Draw simple cube shape
    mov r8d, edx
    mov edx, 12
    mov ecx, 12
    add edi, 2
    add esi, 4
    call fill_rect

    ; Border
    mov r8d, COL_BORDER
    mov edx, 12
    mov ecx, 12
    call draw_rect

    ; 3D effect lines
    sub edi, 2
    sub esi, 4
    mov r8d, COL_BORDER
    mov edx, edi
    add edx, 12
    mov ecx, esi
    call draw_line_h

    pop rsi
    pop rdi
    pop rax
    ret