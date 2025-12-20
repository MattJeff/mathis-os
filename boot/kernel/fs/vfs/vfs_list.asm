; ════════════════════════════════════════════════════════════════════════════
; VFS_LIST.ASM - Directory listing
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; VFS_RELOAD - Reload current directory entries
; ════════════════════════════════════════════════════════════════════════════
vfs_reload:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    ; Check if FAT32 is mounted
    ; fs_readdir now supports subdirectories via path_resolve
    cmp byte [fat32_mounted], 1
    jne .use_mock

    ; Read directory using fs_readdir
    lea rdi, [vfs_current_path]
    lea rsi, [vfs_dirent_buf]       ; Temp buffer for FS_DIRENT entries
    mov edx, VFS_MAX_ENTRIES
    call fs_readdir
    cmp eax, -1
    je .use_mock                    ; Fallback to mock on error
    ; Note: 0 entries is valid (empty folder), don't use mock

    ; Convert FS_DIRENT to VFS_ENTRY
    mov r14d, eax                   ; r14 = entry count
    mov [vfs_entry_count], r14d
    xor r12d, r12d                  ; r12 = index

.convert_loop:
    cmp r12d, r14d
    jge .done

    ; Source: vfs_dirent_buf + i * FS_DIRENT_SIZE
    mov eax, r12d
    imul eax, 64                    ; FS_DIRENT_SIZE = 64
    lea rsi, [vfs_dirent_buf + rax]

    ; Dest: vfs_entries + i * VFS_ENTRY_SIZE
    mov eax, r12d
    imul eax, VFS_ENTRY_SIZE
    lea rdi, [vfs_entries + rax]

    ; Copy name (32 bytes)
    push rdi
    mov ecx, 32
    rep movsb
    pop rdi

    ; Copy size (at offset 32 in both)
    mov eax, [rsi]                  ; rsi now points to offset 32
    mov [rdi + VFS_E_SIZE], eax

    ; Copy flags (at offset 36 in VFS, offset 36 in dirent)
    mov eax, [rsi + 4]              ; Flags at dirent+36
    ; Convert FS_ENTRY_DIR to VFS_FLAG_DIR (both are 0x01, so direct copy)
    mov [rdi + VFS_E_FLAGS], eax

    inc r12d
    jmp .convert_loop

.use_mock:
    ; Create mock entries based on location
    mov eax, [vfs_current_loc]

    cmp eax, VFS_LOC_DESKTOP
    je .mock_desktop

    cmp eax, VFS_LOC_DOWNLOADS
    je .mock_downloads

    cmp eax, VFS_LOC_DOCUMENTS
    je .mock_documents

    ; Default: root
    jmp .mock_root

.mock_root:
    mov dword [vfs_entry_count], 4
    ; Entry 0: desktop/
    lea rdi, [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_desktop]
    call vfs_copy_name
    mov dword [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_DIR
    ; Entry 1: downloads/
    lea rdi, [vfs_entries + 1*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_downloads]
    call vfs_copy_name
    mov dword [vfs_entries + 1*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_DIR
    ; Entry 2: documents/
    lea rdi, [vfs_entries + 2*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_documents]
    call vfs_copy_name
    mov dword [vfs_entries + 2*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_DIR
    ; Entry 3: README.TXT
    lea rdi, [vfs_entries + 3*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_readme]
    call vfs_copy_name
    mov dword [vfs_entries + 3*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_FILE
    mov dword [vfs_entries + 3*VFS_ENTRY_SIZE + VFS_E_SIZE], 128
    jmp .done

.mock_desktop:
    mov dword [vfs_entry_count], 2
    ; Entry 0: Terminal (app)
    lea rdi, [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_terminal]
    call vfs_copy_name
    mov dword [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_FILE
    ; Entry 1: Files (app)
    lea rdi, [vfs_entries + 1*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_files]
    call vfs_copy_name
    mov dword [vfs_entries + 1*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_FILE
    jmp .done

.mock_downloads:
    mov dword [vfs_entry_count], 1
    lea rdi, [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_empty]
    call vfs_copy_name
    mov dword [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_FILE
    jmp .done

.mock_documents:
    mov dword [vfs_entry_count], 1
    lea rdi, [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_NAME]
    lea rsi, [.str_notes]
    call vfs_copy_name
    mov dword [vfs_entries + 0*VFS_ENTRY_SIZE + VFS_E_FLAGS], VFS_FLAG_FILE
    jmp .done

.done:
    mov byte [vfs_dirty], 0
    ; Note: Don't call vfs_notify_change here - caller is responsible
    ; This prevents recursive loops when listeners call vfs_goto

    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Mock strings
.str_desktop:   db "desktop/", 0
.str_downloads: db "download/", 0
.str_documents: db "docs/", 0
.str_readme:    db "README.TXT", 0
.str_terminal:  db "Terminal", 0
.str_files:     db "Files", 0
.str_empty:     db "(empty)", 0
.str_notes:     db "notes.txt", 0

; ════════════════════════════════════════════════════════════════════════════
; VFS_COPY_NAME - Copy string to entry name
; Input: RDI = dest, RSI = src
; ════════════════════════════════════════════════════════════════════════════
vfs_copy_name:
    push rcx
    mov ecx, VFS_MAX_NAME - 1
.copy:
    lodsb
    stosb
    test al, al
    jz .done
    dec ecx
    jnz .copy
    mov byte [rdi], 0
.done:
    pop rcx
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_GET_ENTRIES - Get pointer to entries array
; Output: RAX = entries ptr, EDX = count
; ════════════════════════════════════════════════════════════════════════════
vfs_get_entries:
    lea rax, [vfs_entries]
    mov edx, [vfs_entry_count]
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_GET_PATH - Get current path string
; Output: RAX = path string pointer
; ════════════════════════════════════════════════════════════════════════════
vfs_get_path:
    lea rax, [vfs_current_path]
    ret
