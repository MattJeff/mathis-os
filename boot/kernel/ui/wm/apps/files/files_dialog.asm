; ============================================================================
; FILES_DIALOG.ASM - Dialog open/close/confirm logic
; ============================================================================
; Single Responsibility: Dialog state management
; Preserves: R12-R15
; ============================================================================

[BITS 64]

WMF_DLG_NONE    equ 0
WMF_DLG_NEW     equ 1

; ============================================================================
; WMF_DIALOG_OPEN - Open new folder dialog
; ============================================================================
wmf_dialog_open:
    mov dword [wmf_dialog_mode], WMF_DLG_NEW
    mov dword [wmf_dialog_cursor], 0
    ; Clear input buffer
    lea rdi, [wmf_dialog_input]
    mov ecx, 32
    xor eax, eax
    rep stosb
    mov byte [wm_dirty], 1
    ret

; ============================================================================
; WMF_DIALOG_CLOSE - Close dialog without action
; ============================================================================
wmf_dialog_close:
    mov dword [wmf_dialog_mode], WMF_DLG_NONE
    mov byte [wm_dirty], 1
    ret

; ============================================================================
; WMF_DIALOG_CONFIRM - Confirm and create folder
; ============================================================================
wmf_dialog_confirm:
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
    mov byte [rdi], '/'
    inc rdi
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
