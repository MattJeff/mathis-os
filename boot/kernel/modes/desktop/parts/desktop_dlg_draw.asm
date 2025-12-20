; ============================================================================
; DESKTOP_DLG_DRAW.ASM - Dialog drawing
; ============================================================================
; Single Responsibility: Render dialog UI
; ============================================================================

[BITS 64]

; Dialog dimensions
DESKTOP_DLG_W       equ 300
DESKTOP_DLG_H       equ 150

; ============================================================================
; DESKTOP_DLG_DRAW - Draw dialog if open
; ============================================================================
desktop_dlg_draw:
    cmp byte [desktop_dlg_mode], 0
    je .no_draw

    push r12
    push r13

    ; Center dialog
    mov r12d, [screen_width]
    sub r12d, DESKTOP_DLG_W
    shr r12d, 1                 ; x
    mov r13d, [screen_height]
    sub r13d, DESKTOP_DLG_H
    shr r13d, 1                 ; y

    ; Background
    mov edi, r12d
    mov esi, r13d
    mov edx, DESKTOP_DLG_W
    mov ecx, DESKTOP_DLG_H
    mov r8d, 0x00404050
    call fill_rect

    ; Border
    mov edi, r12d
    mov esi, r13d
    mov edx, DESKTOP_DLG_W
    mov ecx, DESKTOP_DLG_H
    mov r8d, 0x00606080
    call draw_rect

    ; Draw title, options, input
    call .draw_title
    call .draw_options
    call .draw_input_box
    call .draw_hint

    pop r13
    pop r12
.no_draw:
    ret

; --- Private helpers ---
.draw_title:
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 10
    lea rdx, [desktop_dlg_str_title]
    mov ecx, 0x00FFFFFF
    call video_text
    ret

.draw_options:
    ; Option: Folder
    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 35
    lea rdx, [desktop_dlg_str_folder]
    mov ecx, 0x00AAAAAA
    cmp byte [desktop_dlg_select], 0
    jne .folder_done
    mov ecx, 0x0000FF00         ; Green if selected
.folder_done:
    call video_text

    ; Option: File
    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 55
    lea rdx, [desktop_dlg_str_file]
    mov ecx, 0x00AAAAAA
    cmp byte [desktop_dlg_select], 1
    jne .file_done
    mov ecx, 0x0000FF00         ; Green if selected
.file_done:
    call video_text
    ret

.draw_input_box:
    ; Input box background
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 80
    mov edx, 280
    mov ecx, 20
    mov r8d, 0x00202030
    call fill_rect

    ; Input text
    mov edi, r12d
    add edi, 14
    mov esi, r13d
    add esi, 85
    lea rdx, [desktop_dlg_input]
    mov ecx, 0x00FFFFFF
    call video_text

    ; Cursor
    mov eax, [desktop_dlg_cursor]
    imul eax, 8
    add eax, r12d
    add eax, 14
    mov edi, eax
    mov esi, r13d
    add esi, 84
    mov edx, 2
    mov ecx, 12
    mov r8d, 0x00FFFFFF
    call fill_rect
    ret

.draw_hint:
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 110
    lea rdx, [desktop_dlg_str_hint]
    mov ecx, 0x00808080
    call video_text
    ret

; Strings
desktop_dlg_str_title:  db "New Item", 0
desktop_dlg_str_folder: db "[ ] Folder", 0
desktop_dlg_str_file:   db "[ ] File", 0
desktop_dlg_str_hint:   db "Up/Down=Select  Enter=OK  Esc=Cancel", 0

