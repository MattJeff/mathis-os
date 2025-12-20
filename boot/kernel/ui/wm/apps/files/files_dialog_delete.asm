; ============================================================================
; FILES_DIALOG_DELETE.ASM - Delete confirmation
; ============================================================================
; Single Responsibility: Delete selected entry
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_CONFIRM_DELETE - Delete selected file/folder
; ============================================================================
wmf_confirm_delete:
    push rsi
    push rdi
    push rbx

    ; Get selected entry
    call vfs_get_entries
    mov rbx, rax
    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    add rbx, rax

    ; Build full path: current + / + name
    lea rdi, [wmf_new_path]
    call vfs_get_path
    mov rsi, rax
.copy_cur:
    lodsb
    stosb
    test al, al
    jnz .copy_cur
    dec rdi
    cmp rdi, wmf_new_path
    je .add_slash
    cmp byte [rdi - 1], '/'
    je .no_slash
.add_slash:
    mov byte [rdi], '/'
    inc rdi
.no_slash:
    ; Copy entry name (strip trailing /)
    lea rsi, [rbx + VFS_E_NAME]
.copy_name:
    lodsb
    cmp al, '/'
    je .end_name
    test al, al
    jz .end_name
    stosb
    jmp .copy_name
.end_name:
    mov byte [rdi], 0

    ; Delete
    lea rdi, [wmf_new_path]
    call fs_delete

    ; Refresh VFS + desktop icons
    call vfs_reload
    mov dword [wmf_selected], 0
    mov byte [wm_dirty], 1
    mov byte [dicon_dirty], 1       ; Trigger desktop icon refresh
    mov dword [wmf_dialog_mode], WMF_DLG_NONE

    pop rbx
    pop rdi
    pop rsi
    ret
