; FILES_DIALOG_RENAME.ASM - Rename selected entry (preserves R12-R15)

[BITS 64]

wmf_confirm_rename:
    push rsi
    push rdi
    push rbx

    ; Check if new name is empty
    cmp byte [wmf_dialog_input], 0
    je .done

    ; Get selected entry
    call vfs_get_entries
    mov rbx, rax
    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    add rbx, rax

    ; Build old path: current + / + old_name
    lea rdi, [wmf_new_path]
    call vfs_get_path
    mov rsi, rax
.copy_old:
    lodsb
    stosb
    test al, al
    jnz .copy_old
    dec rdi
    cmp rdi, wmf_new_path
    je .slash1
    cmp byte [rdi - 1], '/'
    je .no_slash1
.slash1:
    mov byte [rdi], '/'
    inc rdi
.no_slash1:
    lea rsi, [rbx + VFS_E_NAME]
.copy_old_name:
    lodsb
    cmp al, '/'
    je .old_end
    test al, al
    jz .old_end
    stosb
    jmp .copy_old_name
.old_end:
    mov byte [rdi], 0

    ; Build new path: current + / + new_name
    lea rdi, [wmf_rename_path]
    call vfs_get_path
    mov rsi, rax
.copy_new:
    lodsb
    stosb
    test al, al
    jnz .copy_new
    dec rdi
    cmp rdi, wmf_rename_path
    je .slash2
    cmp byte [rdi - 1], '/'
    je .no_slash2
.slash2:
    mov byte [rdi], '/'
    inc rdi
.no_slash2:
    lea rsi, [wmf_dialog_input]
.copy_new_name:
    lodsb
    stosb
    test al, al
    jnz .copy_new_name

    ; Rename: old → new
    lea rdi, [wmf_new_path]
    lea rsi, [wmf_rename_path]
    call fs_rename

    ; Refresh
    call vfs_reload
    mov byte [wm_dirty], 1

.done:
    mov dword [wmf_dialog_mode], WMF_DLG_NONE
    pop rbx
    pop rdi
    pop rsi
    ret

; Buffer for new path
wmf_rename_path: times 128 db 0
