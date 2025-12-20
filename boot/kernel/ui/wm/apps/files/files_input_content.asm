; ============================================================================
; FILES_INPUT_CONTENT.ASM - Content area input
; ============================================================================
; Single Responsibility: Handle clicks in file list area
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_HANDLE_CONTENT_CLICK - Handle file list click
; Uses: r12d = abs_x, r13d = abs_y
; ============================================================================
wmf_handle_content_click:
    push rbx

    mov eax, r13d
    sub eax, [wmf_win_y]
    sub eax, WMF_TOOLBAR_H
    sub eax, WMF_PADDING
    cmp eax, 0
    jl .done

    xor edx, edx
    mov ecx, WMF_ROW_H
    div ecx

    add eax, [wmf_scroll_pos]
    cmp eax, [wmf_entry_count]
    jge .done

    ; Double-click detection
    cmp eax, [wmf_selected]
    jne .single_click

    call wmf_open_selected
    jmp .done

.single_click:
    mov [wmf_selected], eax

.done:
    pop rbx
    ret

; ============================================================================
; WMF_OPEN_SELECTED - Open selected entry
; ============================================================================
wmf_open_selected:
    push rbx
    push r12

    call vfs_get_entries
    mov rbx, rax

    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    add rbx, rax

    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .done

    ; Push current location to history
    mov edi, [vfs_current_loc]
    call wmf_history_push

    lea rdi, [rbx + VFS_E_NAME]
    call vfs_goto

    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0
    mov byte [wm_dirty], 1

.done:
    pop r12
    pop rbx
    ret
