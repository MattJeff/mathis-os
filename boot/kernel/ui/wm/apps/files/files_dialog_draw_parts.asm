; ============================================================================
; FILES_DIALOG_DRAW_PARTS.ASM - Dialog draw helpers
; ============================================================================
; Uses: r12d = x, r13d = y, r14d = mode (set by parent)
; ============================================================================

[BITS 64]

; Draw title based on mode
wmf_dlg_draw_title:
    lea rdx, [wmf_dlg_str_new]
    cmp r14d, WMF_DLG_DELETE
    jne .t1
    lea rdx, [wmf_dlg_str_del]
    jmp .draw
.t1:
    cmp r14d, WMF_DLG_RENAME
    jne .draw
    lea rdx, [wmf_dlg_str_ren]
.draw:
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 10
    mov ecx, WMF_COL_TEXT
    jmp video_text

; Draw input box and cursor
wmf_dlg_draw_input:
    push rbx
    ; Input background
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
    pop rbx
    jmp fill_rect

; Draw delete filename
wmf_dlg_draw_delname:
    push rbx
    call vfs_get_entries
    mov rbx, rax
    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    lea rdx, [rbx + rax + VFS_E_NAME]
    mov edi, r12d
    add edi, 14
    mov esi, r13d
    add esi, 35
    mov ecx, 0x00FF8080
    pop rbx
    jmp video_text

; Draw hint based on mode
wmf_dlg_draw_hint:
    lea rdx, [wmf_dlg_hint_new]
    mov eax, 110                ; NEW dialog hint y offset
    cmp r14d, WMF_DLG_DELETE
    jne .h1
    lea rdx, [wmf_dlg_hint_del]
    mov eax, 60
    jmp .draw
.h1:
    cmp r14d, WMF_DLG_RENAME
    jne .draw
    lea rdx, [wmf_dlg_hint_ren]
    mov eax, 60
.draw:
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, eax
    mov ecx, WMF_COL_TEXT_DIM
    jmp video_text
