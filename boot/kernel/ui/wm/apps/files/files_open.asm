; ============================================================================
; FILES_OPEN.ASM - Open files in editor
; ============================================================================
; Single Responsibility: Open selected file in editor window
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_OPEN_FILE - Open file in editor from Files app
; Input: RBX = entry pointer (VFS_E_*)
; ============================================================================
wmf_open_file:
    push rsi
    push rdi

    ; Build full path: current_path + "/" + file_name
    lea rdi, [wmf_file_path]
    call vfs_get_path
    mov rsi, rax
.copy_cur:
    lodsb
    test al, al
    jz .cur_done
    stosb
    jmp .copy_cur
.cur_done:
    ; Add slash if needed
    lea rax, [wmf_file_path]
    cmp rdi, rax
    je .add_slash
    cmp byte [rdi - 1], '/'
    je .no_slash
.add_slash:
    mov byte [rdi], '/'
    inc rdi
.no_slash:
    ; Copy file name
    lea rsi, [rbx + VFS_E_NAME]
.copy_name:
    lodsb
    test al, al
    jz .name_done
    stosb
    jmp .copy_name
.name_done:
    mov byte [rdi], 0

    ; Open in editor window
    lea rdi, [wmf_file_path]
    call wme_open_file

    pop rdi
    pop rsi
    ret

; Buffer for file path
wmf_file_path: times 128 db 0

