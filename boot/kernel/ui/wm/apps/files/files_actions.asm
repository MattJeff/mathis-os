; ============================================================================
; FILES_ACTIONS.ASM - File operations
; ============================================================================
; Single Responsibility: Create/delete/rename operations
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_CREATE_FOLDER - Create new folder in current directory
; TODO: Show dialog instead of auto-creating
; ============================================================================
wmf_create_folder:
    push rsi
    push rdi

    ; Build path: current + /NEWFOLDER
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
    lea rsi, [.default_name]

.copy2:
    lodsb
    stosb
    test al, al
    jnz .copy2

    ; Create folder
    lea rdi, [wmf_new_path]
    call fs_mkdir

    ; Refresh view
    call vfs_reload
    mov byte [wm_dirty], 1

    pop rdi
    pop rsi
    ret

.default_name: db "NEWFOLDER", 0
