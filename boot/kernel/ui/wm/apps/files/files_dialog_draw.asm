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

    ; Dialog height: 150 for NEW (has options), 80 for others
    mov ebx, 80
    cmp r14d, WMF_DLG_NEW
    jne .h1
    mov ebx, 150
.h1:

    ; Background
    mov edi, r12d
    mov esi, r13d
    mov edx, 300
    mov ecx, ebx
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
    mov ecx, ebx
    call draw_rect

    ; Title
    call wmf_dlg_draw_title

    ; Content
    cmp r14d, WMF_DLG_DELETE
    je .del
    cmp r14d, WMF_DLG_NEW
    jne .ren
    ; NEW dialog: options + input
    call wmf_dlg_draw_options
    call wmf_dlg_draw_input_new
    jmp .hint
.ren:
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

; Draw file/folder options for NEW dialog
wmf_dlg_draw_options:
    push r12
    push r13
    ; Option: Folder
    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 35
    lea rdx, [wmf_dlg_opt_folder]
    mov ecx, 0x00AAAAAA
    cmp dword [wmf_dialog_select], 0
    jne .folder_done
    mov ecx, 0x0000FF00
.folder_done:
    call video_text

    ; Option: File
    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 55
    lea rdx, [wmf_dlg_opt_file]
    mov ecx, 0x00AAAAAA
    cmp dword [wmf_dialog_select], 1
    jne .file_done
    mov ecx, 0x0000FF00
.file_done:
    call video_text
    pop r13
    pop r12
    ret

; Draw input for NEW dialog (lower position)
wmf_dlg_draw_input_new:
    push r12
    push r13
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
    lea rdx, [wmf_dialog_input]
    mov ecx, 0x00FFFFFF
    call video_text

    ; Cursor
    mov eax, [wmf_dialog_cursor]
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

    pop r13
    pop r12
    ret

; Strings
wmf_dlg_str_new:   db "New Item", 0
wmf_dlg_str_del:   db "Delete?", 0
wmf_dlg_str_ren:   db "Rename", 0
wmf_dlg_opt_folder: db "[ ] Folder", 0
wmf_dlg_opt_file:   db "[ ] File", 0
wmf_dlg_hint_new:  db "Up/Down=Select  Enter=OK  Esc=Cancel", 0
wmf_dlg_hint_del:  db "Enter=Delete  Esc=Cancel", 0
wmf_dlg_hint_ren:  db "Enter=Rename  Esc=Cancel", 0
