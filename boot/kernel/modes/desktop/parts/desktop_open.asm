; ============================================================================
; DESKTOP_OPEN.ASM - Open folder/files functions
; ============================================================================
; Single Responsibility: Open Files window from desktop
; ============================================================================

[BITS 64]

; ============================================================================
; DESKTOP_OPEN_FOLDER - Open Files window at folder path
; Input: RDI = folder name (from dicon entry)
; ============================================================================
desktop_open_folder:
    push rbx
    push r12
    push rsi

    mov r12, rdi                ; Save folder name pointer

    ; Build full path: /DESKTOP/ + folder_name
    lea rdi, [desktop_folder_path]
    lea rsi, [desktop_folder_prefix]
.copy_prefix:
    lodsb
    stosb
    test al, al
    jnz .copy_prefix
    dec rdi                     ; Back to null terminator
    mov rsi, r12                ; Folder name
.copy_name:
    lodsb
    cmp al, '/'                 ; Strip trailing slash
    je .name_done
    test al, al
    jz .name_done
    stosb
    jmp .copy_name
.name_done:
    mov byte [rdi], 0

    ; Navigate VFS to full path
    lea rdi, [desktop_folder_path]
    call vfs_goto

    ; Create Files window on desktop
    mov edi, WM_TYPE_FILES
    mov esi, 120                ; x
    mov edx, 60                 ; y
    mov ecx, WM_DEF_W           ; w
    mov r8d, WM_DEF_H           ; h
    lea r9, [desktop_folder_path]
    call wm_create_window

    pop rsi
    pop r12
    pop rbx
    ret

desktop_folder_prefix: db "/DESKTOP/", 0
desktop_folder_path:   times 64 db 0

; ============================================================================
; DESKTOP_OPEN_FILE - Open file in editor window
; Input: RDI = file name (from dicon entry)
; ============================================================================
desktop_open_file:
    push rbx
    push r12
    push rsi

    mov r12, rdi                ; Save file name pointer

    ; Build full path: /DESKTOP/ + file_name
    lea rdi, [desktop_file_path]
    lea rsi, [desktop_folder_prefix]
.copy_prefix:
    lodsb
    stosb
    test al, al
    jnz .copy_prefix
    dec rdi                     ; Back to null terminator
    mov rsi, r12                ; File name
.copy_name:
    lodsb
    test al, al
    jz .name_done
    stosb
    jmp .copy_name
.name_done:
    mov byte [rdi], 0

    ; Open in editor window
    lea rdi, [desktop_file_path]
    call wme_open_file

    pop rsi
    pop r12
    pop rbx
    ret

desktop_file_path:   times 128 db 0

; ============================================================================
; DESKTOP_OPEN_FILES - Open Files app window (from icon click)
; ============================================================================
desktop_open_files:
    push rbx

    ; Create Files window centered on screen
    mov edi, WM_TYPE_FILES
    ; x = (screen_width - WM_DEF_W) / 2
    mov esi, [screen_width]
    sub esi, WM_DEF_W
    shr esi, 1
    ; y = (screen_height - WM_DEF_H) / 2
    mov edx, [screen_height]
    sub edx, WM_DEF_H
    shr edx, 1
    mov ecx, WM_DEF_W
    mov r8d, WM_DEF_H
    lea r9, [desktop_str_files]
    call wm_create_window

    pop rbx
    ret

; ============================================================================
; DESKTOP_ON_VFS_CHANGE - Called when VFS changes
; ============================================================================
desktop_on_vfs_change:
    call dicon_refresh
    ret

; ============================================================================
; DESKTOP_HANDLE_KEY - Handle keyboard in desktop mode
; Input: EDI = scancode
; ============================================================================
desktop_handle_key:
    call wm_on_key
    ret

