; ============================================================================
; FILES_DIALOG_DRAW.ASM - Dialog rendering
; ============================================================================
; Single Responsibility: Draw dialog overlay
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_DRAW_DIALOG - Draw dialog box
; ============================================================================
wmf_draw_dialog:
    push r12
    push r13

    ; Calculate dialog position (centered)
    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W
    mov eax, [wmf_win_w]
    sub eax, WMF_SIDEBAR_W
    sub eax, 300
    shr eax, 1
    add r12d, eax

    mov r13d, [wmf_win_y]
    add r13d, WMF_TOOLBAR_H
    add r13d, 50

    ; Background
    mov edi, r12d
    mov esi, r13d
    mov edx, 300
    mov ecx, 80
    mov r8d, 0x00404050
    call fill_rect

    ; Border
    mov edi, r12d
    mov esi, r13d
    mov edx, 300
    mov ecx, 80
    mov r8d, 0x00606080
    call draw_rect

    ; Title
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 10
    lea rdx, [.str_title]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; Input box background
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 30
    mov edx, 280
    mov ecx, 20
    mov r8d, 0x00202030
    call fill_rect

    ; Input text
    mov edi, r12d
    add edi, 14
    mov esi, r13d
    add esi, 35
    lea rdx, [wmf_dialog_input]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; Cursor
    mov eax, [wmf_dialog_cursor]
    imul eax, 8
    add eax, r12d
    add eax, 14
    mov edi, eax
    mov esi, r13d
    add esi, 34
    mov edx, 2
    mov ecx, 12
    mov r8d, WMF_COL_TEXT
    call fill_rect

    ; Hint text
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 60
    lea rdx, [.str_hint]
    mov ecx, WMF_COL_TEXT_DIM
    call video_text

    pop r13
    pop r12
    ret

.str_title: db "New Folder", 0
.str_hint:  db "Enter=Create  Esc=Cancel", 0
