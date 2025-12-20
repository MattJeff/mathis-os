; ════════════════════════════════════════════════════════════════════════════
; FILES_LOADER.ASM - Directory loading from filesystem
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FA_LOAD_DIRECTORY - Load directory entries from filesystem
; Uses fs_svc to get real file listing, falls back to mock data
; ════════════════════════════════════════════════════════════════════════════
fa_load_directory:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    ; Try to get filesystem service
    mov edi, SVC_FS
    call get_service
    test rax, rax
    jz .use_mock                    ; No FS service, use mock data

    mov r15, rax                    ; r15 = fs_vtable

    ; Call fs_readdir("/", buffer, max_entries)
    lea rdi, [fa_root_path]         ; path = "/"
    lea rsi, [fa_dirent_buf]        ; buffer for results
    mov edx, FA_MAX_ENTRIES         ; max entries
    call [r15 + FS_READDIR]

    cmp eax, -1
    je .use_mock                    ; Error, use mock data
    test eax, eax
    jz .use_mock                    ; No entries, use mock data

    ; eax = number of entries read
    mov r14d, eax                   ; r14 = entry count
    mov [fa_entry_count], eax

    ; Convert FS_DIRENT entries to FILE_ENTRY format
    xor r12d, r12d                  ; r12 = current index
    lea r13, [fa_dirent_buf]        ; r13 = source dirent

.convert_loop:
    cmp r12d, r14d
    jge .load_done

    ; Calculate destination pointers
    mov eax, r12d
    imul eax, FILE_ENTRY_SIZE       ; 32 bytes per entry
    lea rbx, [fa_entries + rax]     ; rbx = dest FILE_ENTRY

    ; Calculate name buffer pointer
    mov eax, r12d
    shl eax, 5                      ; * 32 bytes per name
    lea rcx, [fa_name_bufs + rax]   ; rcx = name buffer

    ; Calculate date buffer pointer
    mov eax, r12d
    shl eax, 4                      ; * 16 bytes per date
    lea rdx, [fa_date_bufs + rax]   ; rdx = date buffer

    ; Copy name from dirent to name buffer
    push rcx
    push rdx
    mov rdi, rcx                    ; dest = name buffer
    lea rsi, [r13 + FA_FS_DIRENT_NAME] ; src = dirent name
    mov ecx, 31                     ; max 31 chars
.copy_name:
    lodsb
    stosb
    test al, al
    jz .name_copied
    dec ecx
    jnz .copy_name
    mov byte [rdi], 0               ; Ensure null terminated
.name_copied:
    pop rdx
    pop rcx

    ; Set name pointer in FILE_ENTRY
    mov [rbx + FE_NAME], rcx

    ; Copy size
    mov eax, [r13 + FA_FS_DIRENT_SIZE_OFF]
    mov [rbx + FE_SIZE], eax

    ; Convert flags (FS_ENTRY_* to FEF_*)
    mov eax, [r13 + FA_FS_DIRENT_FLAGS]
    xor ecx, ecx
    test eax, FA_FS_ENTRY_DIR
    jz .not_dir_flag
    or ecx, FEF_DIRECTORY
.not_dir_flag:
    mov [rbx + FE_FLAGS], ecx

    ; Set date pointer (use placeholder for now)
    lea rax, [fa_mock_mod]          ; TODO: Convert timestamp to string
    mov [rbx + FE_MOD_DATE], rax

    ; Clear reserved
    mov qword [rbx + FE_RESERVED], 0

    ; Next entry
    add r13, FA_FS_DIRENT_SIZE
    inc r12d
    jmp .convert_loop

.use_mock:
    ; Fallback: create mock entries
    mov dword [fa_entry_count], 4

    ; Entry 0: PROJECTS/
    lea rax, [fa_mock_name_0]
    mov [fa_entries + 0*32 + FE_NAME], rax
    mov dword [fa_entries + 0*32 + FE_SIZE], 0
    mov dword [fa_entries + 0*32 + FE_FLAGS], FEF_DIRECTORY
    lea rax, [fa_mock_mod]
    mov [fa_entries + 0*32 + FE_MOD_DATE], rax

    ; Entry 1: DOCS/
    lea rax, [fa_mock_name_1]
    mov [fa_entries + 1*32 + FE_NAME], rax
    mov dword [fa_entries + 1*32 + FE_SIZE], 0
    mov dword [fa_entries + 1*32 + FE_FLAGS], FEF_DIRECTORY
    lea rax, [fa_mock_mod]
    mov [fa_entries + 1*32 + FE_MOD_DATE], rax

    ; Entry 2: README.TXT
    lea rax, [fa_mock_name_2]
    mov [fa_entries + 2*32 + FE_NAME], rax
    mov dword [fa_entries + 2*32 + FE_SIZE], 45
    mov dword [fa_entries + 2*32 + FE_FLAGS], 0
    lea rax, [fa_mock_mod]
    mov [fa_entries + 2*32 + FE_MOD_DATE], rax

    ; Entry 3: HELLO.ASM
    lea rax, [fa_mock_name_3]
    mov [fa_entries + 3*32 + FE_NAME], rax
    mov dword [fa_entries + 3*32 + FE_SIZE], 128
    mov dword [fa_entries + 3*32 + FE_FLAGS], 0
    lea rax, [fa_mock_mod]
    mov [fa_entries + 3*32 + FE_MOD_DATE], rax

.load_done:
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
