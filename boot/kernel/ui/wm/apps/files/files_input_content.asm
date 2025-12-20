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
    push rcx
    push rsi
    push rdi
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

    ; Build full path: current_path + "/" + folder_name
    lea rdi, [wmf_nav_path]
    call vfs_get_path
    mov rsi, rax
.copy_cur:
    lodsb
    test al, al
    jz .cur_done
    stosb
    jmp .copy_cur
.cur_done:
    ; Add slash if needed (not if path ends with / or is empty)
    lea rax, [wmf_nav_path]
    cmp rdi, rax
    je .add_slash
    cmp byte [rdi - 1], '/'
    je .no_slash
.add_slash:
    mov byte [rdi], '/'
    inc rdi
.no_slash:
    ; Copy folder name (strip trailing /)
    lea rsi, [rbx + VFS_E_NAME]
.copy_name:
    lodsb
    cmp al, '/'
    je .name_done
    test al, al
    jz .name_done
    stosb
    jmp .copy_name
.name_done:
    mov byte [rdi], 0

    ; Navigate to full path
    lea rdi, [wmf_nav_path]
    call vfs_goto

    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0
    mov byte [wm_dirty], 1

.done:
    pop r12
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; Buffer for navigation path
wmf_nav_path: times 128 db 0
