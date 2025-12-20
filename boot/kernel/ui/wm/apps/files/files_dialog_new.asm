; ============================================================================
; FILES_DIALOG_NEW.ASM - New folder confirmation
; ============================================================================
; Single Responsibility: Create new folder
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_CONFIRM_NEW - Create new folder
; ============================================================================
wmf_confirm_new:
    push rsi
    push rdi

    ; Check if input is empty
    cmp byte [wmf_dialog_input], 0
    je .done

    ; Build path: current + /name
    lea rdi, [wmf_new_path]
    call vfs_get_path
    mov rsi, rax
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy
    dec rdi
    cmp rdi, wmf_new_path
    je .add_slash
    cmp byte [rdi - 1], '/'
    je .no_slash
.add_slash:
    mov byte [rdi], '/'
    inc rdi
.no_slash:
    lea rsi, [wmf_dialog_input]
.copy2:
    lodsb
    stosb
    test al, al
    jnz .copy2

    ; Create folder
    lea rdi, [wmf_new_path]
    call fs_mkdir

    ; Refresh
    call vfs_reload
    mov byte [wm_dirty], 1

.done:
    mov dword [wmf_dialog_mode], WMF_DLG_NONE
    pop rdi
    pop rsi
    ret
