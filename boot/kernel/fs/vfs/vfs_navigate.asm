; ════════════════════════════════════════════════════════════════════════════
; VFS_NAVIGATE.ASM - Directory navigation
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; VFS_GOTO - Navigate to a path
; Input: RDI = path string pointer
; Output: EAX = 1 success, 0 fail
; ════════════════════════════════════════════════════════════════════════════
vfs_goto:
    push rbx
    push rcx
    push rsi
    push rdi

    mov rbx, rdi                    ; Save path

    ; Copy path to current
    lea rdi, [vfs_current_path]
    mov rsi, rbx
    mov ecx, VFS_MAX_PATH - 1
.copy:
    lodsb
    stosb
    test al, al
    jz .copy_done
    dec ecx
    jnz .copy
    mov byte [rdi], 0
.copy_done:

    ; Detect location type
    ; Compare with both formats: "desktop/" (from click) and "/desktop" (from sidebar)

    ; Check desktop/ or /desktop
    lea rdi, [.str_desktop1]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_desktop
    lea rdi, [.str_desktop2]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_desktop

    ; Check downloads/ or /downloads
    lea rdi, [.str_downloads1]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_downloads
    lea rdi, [.str_downloads2]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_downloads

    ; Check documents/ or /documents
    lea rdi, [.str_documents1]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_documents
    lea rdi, [.str_documents2]
    mov rsi, rbx
    call vfs_str_equal
    test eax, eax
    jnz .is_documents

    ; Default: root
    mov dword [vfs_current_loc], VFS_LOC_ROOT
    jmp .reload

.str_desktop1:   db "desktop/", 0
.str_desktop2:   db "/desktop", 0
.str_downloads1: db "download/", 0
.str_downloads2: db "/download", 0
.str_documents1: db "docs/", 0
.str_documents2: db "/docs", 0

.is_desktop:
    mov dword [vfs_current_loc], VFS_LOC_DESKTOP
    jmp .reload

.is_downloads:
    mov dword [vfs_current_loc], VFS_LOC_DOWNLOADS
    jmp .reload

.is_documents:
    mov dword [vfs_current_loc], VFS_LOC_DOCUMENTS

.reload:
    ; Mark dirty and reload
    mov byte [vfs_dirty], 1
    call vfs_reload

    mov eax, 1
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_GOTO_LOC - Navigate by location ID
; Input: EDI = location ID (VFS_LOC_*)
; ════════════════════════════════════════════════════════════════════════════
vfs_goto_loc:
    push rdi

    cmp edi, VFS_LOC_DESKTOP
    je .desktop
    cmp edi, VFS_LOC_DOWNLOADS
    je .downloads
    cmp edi, VFS_LOC_DOCUMENTS
    je .documents
    ; Default: root
    lea rdi, [vfs_path_root]
    jmp .do_goto

.desktop:
    lea rdi, [vfs_path_desktop]
    jmp .do_goto

.downloads:
    lea rdi, [vfs_path_downloads]
    jmp .do_goto

.documents:
    lea rdi, [vfs_path_documents]

.do_goto:
    call vfs_goto
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_STR_EQUAL - Compare two strings
; Input: RDI = str1, RSI = str2
; Output: EAX = 1 if equal, 0 if not
; ════════════════════════════════════════════════════════════════════════════
vfs_str_equal:
    push rdi
    push rsi
.cmp:
    mov al, [rdi]
    mov ah, [rsi]
    cmp al, ah
    jne .not_equal
    test al, al
    jz .equal
    inc rdi
    inc rsi
    jmp .cmp
.equal:
    mov eax, 1
    jmp .done
.not_equal:
    xor eax, eax
.done:
    pop rsi
    pop rdi
    ret
