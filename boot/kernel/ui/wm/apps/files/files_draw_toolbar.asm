; ============================================================================
; FILES_DRAW_TOOLBAR.ASM - Toolbar drawing
; ============================================================================
; Single Responsibility: Draw toolbar with < > buttons and path
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_DRAW_TOOLBAR - Draw toolbar
; ============================================================================
wmf_draw_toolbar:
    push r12
    push r13

    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W
    mov r13d, [wmf_win_y]

    ; Back button <
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 5
    mov edx, 28
    mov ecx, 22
    mov r8d, WMF_COL_BTN
    call fill_rect

    mov edi, r12d
    add edi, 19
    mov esi, r13d
    add esi, 9
    lea rdx, [.str_back]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; Forward button >
    mov edi, r12d
    add edi, 42
    mov esi, r13d
    add esi, 5
    mov edx, 28
    mov ecx, 22
    mov r8d, WMF_COL_BTN
    call fill_rect

    mov edi, r12d
    add edi, 51
    mov esi, r13d
    add esi, 9
    lea rdx, [.str_fwd]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; Path display
    mov edi, r12d
    add edi, 80
    mov esi, r13d
    add esi, 10
    call vfs_get_path
    mov rdx, rax
    mov ecx, WMF_COL_TEXT
    call video_text

    ; NEW button (right side)
    mov eax, [wmf_win_w]
    sub eax, WMF_SIDEBAR_W
    sub eax, 60

    mov edi, r12d
    add edi, eax
    push rax
    mov esi, r13d
    add esi, 5
    mov edx, 50
    mov ecx, 22
    mov r8d, WMF_COL_BTN
    call fill_rect
    pop rax

    mov edi, r12d
    add edi, eax
    add edi, 12
    mov esi, r13d
    add esi, 9
    lea rdx, [.str_new]
    mov ecx, WMF_COL_TEXT
    call video_text

    pop r13
    pop r12
    ret

.str_back:  db "<", 0
.str_fwd:   db ">", 0
.str_new:   db "+ NEW", 0
