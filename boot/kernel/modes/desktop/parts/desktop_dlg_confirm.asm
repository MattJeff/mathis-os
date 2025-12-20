; ============================================================================
; DESKTOP_DLG_CONFIRM.ASM - Create file/folder on confirm
; ============================================================================
; Single Responsibility: Create file or folder in /DESKTOP
; ============================================================================

[BITS 64]

; ============================================================================
; DESKTOP_DLG_CONFIRM - Confirm and create file/folder
; ============================================================================
desktop_dlg_confirm:
    cmp byte [desktop_dlg_input], 0
    je desktop_dlg_close        ; Empty name, just close

    ; Build path: /DESKTOP/ + name
    lea rdi, [desktop_dlg_path]
    lea rsi, [desktop_folder_prefix]
.copy_pre:
    lodsb
    stosb
    test al, al
    jnz .copy_pre
    dec rdi
    lea rsi, [desktop_dlg_input]
.copy_name:
    lodsb
    stosb
    test al, al
    jnz .copy_name

    ; Create based on selection
    cmp byte [desktop_dlg_select], 0
    jne .create_file

    ; Create folder
    lea rdi, [desktop_dlg_path]
    call fs_mkdir
    jmp .refresh

.create_file:
    ; Create empty file using crud_create_file
    lea rdi, [desktop_dlg_path]
    mov esi, 0x04               ; FS_O_CREATE
    call crud_create_file
    cmp eax, -1
    je .refresh
    mov edi, eax
    call fs_close

.refresh:
    mov byte [dicon_dirty], 1
    mov byte [desktop_needs_redraw], 1
    mov byte [desktop_dlg_mode], DESKTOP_DLG_NONE
    ret

