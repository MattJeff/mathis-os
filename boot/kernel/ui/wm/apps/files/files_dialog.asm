; ============================================================================
; FILES_DIALOG.ASM - Dialog state management
; ============================================================================

[BITS 64]

WMF_DLG_NONE    equ 0
WMF_DLG_NEW     equ 1
WMF_DLG_DELETE  equ 2
WMF_DLG_RENAME  equ 3

; Open new file/folder dialog
wmf_dialog_open:
    mov dword [wmf_dialog_mode], WMF_DLG_NEW
    mov dword [wmf_dialog_select], 0    ; Default to folder
    mov dword [wmf_dialog_cursor], 0
    lea rdi, [wmf_dialog_input]
    mov ecx, 32
    xor eax, eax
    rep stosb
    mov byte [wm_dirty], 1
    ret

; Open delete confirmation
wmf_dialog_open_delete:
    mov eax, [wmf_selected]
    cmp eax, [wmf_entry_count]
    jge .skip
    mov dword [wmf_dialog_mode], WMF_DLG_DELETE
    mov byte [wm_dirty], 1
.skip:
    ret

; Open rename dialog with current name
wmf_dialog_open_rename:
    push rsi
    push rdi
    push rcx
    mov eax, [wmf_selected]
    cmp eax, [wmf_entry_count]
    jge .done
    ; Get selected entry name
    call vfs_get_entries
    mov rsi, rax
    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    lea rsi, [rsi + rax + VFS_E_NAME]
    ; Copy name to input (strip trailing /)
    lea rdi, [wmf_dialog_input]
    mov ecx, 30
.copy:
    lodsb
    cmp al, '/'
    je .end
    test al, al
    jz .end
    stosb
    dec ecx
    jnz .copy
.end:
    mov byte [rdi], 0
    ; Set cursor at end
    lea rax, [wmf_dialog_input]
    sub rdi, rax
    mov [wmf_dialog_cursor], edi
    mov dword [wmf_dialog_mode], WMF_DLG_RENAME
    mov byte [wm_dirty], 1
.done:
    pop rcx
    pop rdi
    pop rsi
    ret

; Close without action
wmf_dialog_close:
    mov dword [wmf_dialog_mode], WMF_DLG_NONE
    mov byte [wm_dirty], 1
    ret

; Dispatch to handler
wmf_dialog_confirm:
    mov eax, [wmf_dialog_mode]
    cmp eax, WMF_DLG_NEW
    je wmf_confirm_new
    cmp eax, WMF_DLG_DELETE
    je wmf_confirm_delete
    cmp eax, WMF_DLG_RENAME
    je wmf_confirm_rename
    ret
