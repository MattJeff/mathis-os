; ============================================================================
; FILES_DRAW_LIST.ASM - Finder-style icon grid
; ============================================================================

[BITS 64]

; WMF_DRAW_FILES - Draw files as icon grid (Finder style)
wmf_draw_files:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Content area start
    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W + 20          ; Left margin
    mov r13d, [wmf_win_y]
    add r13d, WMF_TOOLBAR_H + 20          ; Top margin

    ; Calculate columns that fit
    mov eax, [wmf_win_w]
    sub eax, WMF_SIDEBAR_W + 40           ; Available width
    xor edx, edx
    mov ecx, WMF_ICON_SPACING
    div ecx
    mov [wmf_cols], eax                   ; Columns that fit

    call vfs_get_entries
    mov [wmf_vfs_ptr], rax
    mov [wmf_entry_count], edx
    mov dword [wmf_loop_idx], 0

.loop:
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_entry_count]
    jge .done

    ; Calculate grid position
    xor edx, edx
    mov ecx, [wmf_cols]
    test ecx, ecx
    jz .done
    div ecx                               ; eax=row, edx=col

    ; X = base + col * spacing
    imul edx, WMF_ICON_SPACING
    add edx, r12d
    mov [wmf_icon_x], edx

    ; Y = base + row * (icon_size + label_h + spacing)
    imul eax, WMF_ICON_SIZE + WMF_ICON_LABEL_H + 16
    add eax, r13d
    mov [wmf_icon_y], eax

    ; Get entry pointer
    mov eax, [wmf_loop_idx]
    imul eax, VFS_ENTRY_SIZE
    mov rbx, [wmf_vfs_ptr]
    add rbx, rax

    ; Selection highlight (blue rounded rect behind icon)
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_selected]
    jne .no_sel
    mov edi, [wmf_icon_x]
    sub edi, 4
    mov esi, [wmf_icon_y]
    sub esi, 4
    mov edx, WMF_ICON_SIZE + 8
    mov ecx, WMF_ICON_SIZE + WMF_ICON_LABEL_H + 8
    mov r8d, WMF_COL_SEL_BLUE
    call fill_rect
.no_sel:

    ; Draw icon (large folder or file icon)
    mov edi, [wmf_icon_x]
    mov esi, [wmf_icon_y]
    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .file_icon

    ; Folder icon (64x52 blue rectangle)
    mov edx, WMF_ICON_SIZE
    mov ecx, WMF_ICON_SIZE - 12
    mov r8d, WMF_COL_FOLDER
    jmp .draw_icon

.file_icon:
    ; File icon (52x64 white/gray rectangle)
    add edi, 6
    mov edx, WMF_ICON_SIZE - 12
    mov ecx, WMF_ICON_SIZE
    mov r8d, WMF_COL_FILE

.draw_icon:
    call fill_rect

    ; Draw file extension on file icons
    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jnz .draw_label

    ; "TXT" label on file
    mov edi, [wmf_icon_x]
    add edi, 18
    mov esi, [wmf_icon_y]
    add esi, 28
    lea rdx, [wmf_str_txt]
    mov ecx, WMF_COL_TEXT_DIM
    call video_text

.draw_label:
    ; Draw name below icon
    mov edi, [wmf_icon_x]
    mov esi, [wmf_icon_y]
    add esi, WMF_ICON_SIZE + 6
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

wmf_str_txt: db "TXT", 0
