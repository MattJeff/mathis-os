; ============================================================================
; FILES_DIALOG_DRAW.ASM - Dialog rendering
; ============================================================================
; Single Responsibility: Draw dialog overlay
; ============================================================================

[BITS 64]

; Uses: r12d = dialog x, r13d = dialog y, r14d = mode
wmf_draw_dialog:
    push rbx
    push r12
    push r13
    push r14

    mov r14d, [wmf_dialog_mode]

    ; Calculate centered position
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

    ; Border (red for delete)
    mov r8d, 0x00606080
    cmp r14d, WMF_DLG_DELETE
    jne .b1
    mov r8d, 0x00A04040
.b1:
    mov edi, r12d
    mov esi, r13d
    mov edx, 300
    mov ecx, 80
    call draw_rect

    ; Title
    call wmf_dlg_draw_title

    ; Content
    cmp r14d, WMF_DLG_DELETE
    je .del
    call wmf_dlg_draw_input
    jmp .hint
.del:
    call wmf_dlg_draw_delname

.hint:
    call wmf_dlg_draw_hint

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Strings
wmf_dlg_str_new:   db "New Folder", 0
wmf_dlg_str_del:   db "Delete?", 0
wmf_dlg_str_ren:   db "Rename", 0
wmf_dlg_hint_new:  db "Enter=OK  Esc=Cancel", 0
wmf_dlg_hint_del:  db "Enter=Delete  Esc=Cancel", 0
wmf_dlg_hint_ren:  db "Enter=Rename  Esc=Cancel", 0
