; ============================================================================
; FILES_DRAW_LIST.ASM - File list drawing
; ============================================================================

[BITS 64]

; WMF_DRAW_FILES - Draw file list in content area
wmf_draw_files:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W + WMF_PADDING
    mov r13d, [wmf_win_y]
    add r13d, WMF_TOOLBAR_H + WMF_PADDING
    mov r14d, [wmf_win_w]
    sub r14d, WMF_SIDEBAR_W + WMF_PADDING * 2

    call vfs_get_entries
    mov [wmf_vfs_ptr], rax
    mov [wmf_entry_count], edx
    mov dword [wmf_loop_idx], 0

.loop:
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_entry_count]
    jge .done
    mov ecx, eax
    sub ecx, [wmf_scroll_pos]
    cmp ecx, WMF_MAX_VISIBLE
    jge .done
    cmp ecx, 0
    jl .next

    imul ecx, WMF_ROW_H
    add ecx, r13d
    mov [wmf_cur_y], ecx

    mov eax, [wmf_loop_idx]
    imul eax, VFS_ENTRY_SIZE
    mov rbx, [wmf_vfs_ptr]
    add rbx, rax

    ; Selection highlight
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_selected]
    jne .no_sel
    mov edi, r12d
    mov esi, [wmf_cur_y]
    mov edx, r14d
    mov ecx, WMF_ROW_H
    mov r8d, WMF_COL_SEL
    call fill_rect

.no_sel:
    ; Icon (folder=14x12, file=12x14)
    mov edi, r12d
    add edi, 4
    mov esi, [wmf_cur_y]
    add esi, 3
    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .file_icon
    mov edx, 14
    mov ecx, 12
    mov r8d, WMF_COL_FOLDER
    jmp .draw_icon
.file_icon:
    mov edx, 12
    mov ecx, 14
    mov r8d, WMF_COL_FILE
.draw_icon:
    call fill_rect

    ; Name
    mov edi, r12d
    add edi, 24
    mov esi, [wmf_cur_y]
    add esi, 4
    lea rdx, [rbx + VFS_E_NAME]
    mov ecx, WMF_COL_TEXT
    call video_text

.next:
    inc dword [wmf_loop_idx]
    jmp .loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
