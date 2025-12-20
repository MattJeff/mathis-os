; ============================================================================
; FILES_DIALOG_NEW.ASM - New folder confirmation
; ============================================================================
; Single Responsibility: Create new folder
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_CONFIRM_NEW - Create new file or folder
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

    ; Create folder or file based on selection
    cmp dword [wmf_dialog_select], 0
    jne .create_file

    ; Create folder
    lea rdi, [wmf_new_path]
    call fs_mkdir
    jmp .refresh

.create_file:
    ; Create empty file using crud_create_file
    lea rdi, [wmf_new_path]
    mov esi, 0x04               ; FS_O_CREATE
    call crud_create_file
    cmp eax, -1
    je .refresh
    mov edi, eax
    call fs_close

.refresh:
    ; Refresh VFS + desktop icons
    call vfs_reload
    mov byte [wm_dirty], 1
    mov byte [dicon_dirty], 1       ; Trigger desktop icon refresh

.done:
    mov dword [wmf_dialog_mode], WMF_DLG_NONE
    pop rdi
    pop rsi
    ret
