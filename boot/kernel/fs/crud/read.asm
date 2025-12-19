; ============================================================================
; CRUD/READ.ASM - File Read Service (SOLID)
; ============================================================================
; Single Responsibility: Read files and directories from FAT32
;
; Public API:
;   crud_read(fd, buffer, size) -> bytes_read or -1
;   crud_read_file(path, buffer, max_size) -> bytes_read or -1
;   crud_readdir(path, buffer, max_entries) -> count or -1
;   crud_stat(path, stat_buf) -> 1 or 0
;   crud_exists(path) -> 1 or 0
;
; Dependencies: fat32.asm (low-level), fs_svc.asm (file descriptors)
; ============================================================================

[BITS 64]

; ============================================================================
; CRUD_READ - Read from an open file descriptor
; ============================================================================
; Input:  EDI = file descriptor
;         RSI = buffer
;         EDX = size (bytes to read)
; Output: EAX = bytes read, or -1 on error
; ============================================================================
crud_read:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; --- VALIDATE FD ---
    call crud_validate_fd
    test rax, rax
    jz .read_error

    mov rbx, rax                    ; rbx = fd entry pointer
    mov r12, rsi                    ; r12 = buffer
    mov r13d, edx                   ; r13 = bytes to read
    xor r14d, r14d                  ; r14 = bytes read so far

    ; --- CHECK EOF ---
    mov eax, [rbx + FS_FD_POS]
    cmp eax, [rbx + FS_FD_FILE_SIZE]
    jge .read_eof

    ; --- LIMIT TO REMAINING ---
    mov ecx, [rbx + FS_FD_FILE_SIZE]
    sub ecx, eax                    ; remaining bytes
    cmp r13d, ecx
    jle .size_ok
    mov r13d, ecx                   ; clamp to remaining

.size_ok:
    mov r15d, [rbx + FS_FD_CUR_CLUSTER]

.read_loop:
    ; Check if done
    cmp r14d, r13d
    jge .read_complete

    ; Read current cluster
    mov eax, r15d
    mov rdi, r12
    call fat32_read_cluster

    ; Calculate bytes from this cluster
    mov ecx, [fat32_bytes_per_cluster]

    ; Don't read more than needed
    mov eax, r13d
    sub eax, r14d                   ; remaining to read
    cmp ecx, eax
    jle .use_full
    mov ecx, eax

.use_full:
    add r14d, ecx                   ; update bytes read
    add r12, rcx                    ; advance buffer

    ; Get next cluster
    mov eax, r15d
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .read_complete
    mov r15d, eax
    jmp .read_loop

.read_complete:
    ; Update fd position and current cluster
    add [rbx + FS_FD_POS], r14d
    mov [rbx + FS_FD_CUR_CLUSTER], r15d
    mov eax, r14d
    jmp .read_done

.read_eof:
    xor eax, eax
    jmp .read_done

.read_error:
    mov eax, -1

.read_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_READ_FILE - Read entire file by path (convenience function)
; ============================================================================
; Input:  RDI = path
;         RSI = buffer
;         EDX = max size
; Output: EAX = bytes read or -1
; ============================================================================
crud_read_file:
    push rbx
    push r12
    push r13

    mov r12, rsi                    ; buffer
    mov r13d, edx                   ; max size

    ; Open file
    mov esi, FS_O_RDONLY
    call crud_open_readonly
    cmp eax, -1
    je .rf_error

    mov ebx, eax                    ; fd

    ; Read content
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call crud_read

    push rax                        ; save bytes read

    ; Close file
    mov edi, ebx
    call fs_close

    pop rax
    jmp .rf_done

.rf_error:
    mov eax, -1

.rf_done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; CRUD_READDIR - Read directory entries
; ============================================================================
; Input:  RDI = path ("/" for root)
;         RSI = buffer (array of FS_DIRENT_SIZE entries)
;         EDX = max entries
; Output: EAX = number of entries, or -1 on error
; ============================================================================
crud_readdir:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; --- VALIDATION ---
    cmp byte [fat32_mounted], 1
    jne .readdir_error

    mov r12, rdi                    ; path (unused for now, root only)
    mov r13, rsi                    ; output buffer
    mov r14d, edx                   ; max entries
    xor r15d, r15d                  ; entry count

    ; --- READ ROOT DIRECTORY ---
    mov eax, [fat32_root_cluster]
    mov rdi, fat32_sector_buffer
    call fat32_read_cluster
    test eax, eax
    jz .readdir_error

    ; --- PARSE ENTRIES ---
    mov rbx, fat32_sector_buffer
    mov ecx, [fat32_sectors_per_cluster]
    imul ecx, 16                    ; 16 entries per sector

.parse_entry:
    ; Check max
    cmp r15d, r14d
    jge .readdir_done

    ; Check end of dir
    cmp byte [rbx], 0
    je .readdir_done

    ; Skip deleted
    cmp byte [rbx], 0xE5
    je .next_entry

    ; Skip LFN
    mov al, [rbx + FAT32_DIR_ATTR]
    cmp al, FAT32_ATTR_LFN
    je .next_entry

    ; Skip volume label
    test al, FAT32_ATTR_VOLUME_ID
    jnz .next_entry

    ; --- COPY ENTRY ---
    push rcx
    push rbx

    ; Calculate output position
    mov eax, r15d
    imul eax, FS_DIRENT_SIZE
    lea rdi, [r13 + rax]

    ; Convert 8.3 name
    call crud_convert_name_83

    ; Copy size
    mov eax, [rbx + FAT32_DIR_SIZE]
    mov [rdi + FS_DIRENT_SIZE_OFF], eax

    ; Set flags
    call crud_get_entry_flags
    mov [rdi + FS_DIRENT_FLAGS], eax

    ; Get cluster
    movzx eax, word [rbx + FAT32_DIR_CLUSTER_HI]
    shl eax, 16
    or ax, word [rbx + FAT32_DIR_CLUSTER_LO]
    mov [rdi + FS_DIRENT_CLUSTER], eax

    ; Timestamps (zeros for now)
    mov qword [rdi + FS_DIRENT_MTIME], 0
    mov qword [rdi + FS_DIRENT_CTIME], 0
    mov dword [rdi + FS_DIRENT_RESERVED], 0

    pop rbx
    pop rcx

    inc r15d

.next_entry:
    add rbx, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jnz .parse_entry

.readdir_done:
    mov eax, r15d
    jmp .readdir_exit

.readdir_error:
    mov eax, -1

.readdir_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_STAT - Get file information
; ============================================================================
; Input:  RDI = path
;         RSI = stat buffer (FS_STAT_STRUCT_SIZE bytes)
; Output: EAX = 1 on success, 0 if not found
; ============================================================================
crud_stat:
    push rbx
    push rcx
    push r12

    mov r12, rsi                    ; stat buffer

    ; Validate
    cmp byte [fat32_mounted], 1
    jne .stat_error

    ; Convert path
    mov rsi, rdi
    lea rdi, [crud_read_temp_name]
    call fat32_convert_name

    ; Find file
    mov eax, [fat32_root_cluster]
    lea rsi, [crud_read_temp_name]
    call fat32_find_file

    test rax, rax
    jz .stat_error

    ; Fill stat buffer
    ; Size
    mov ebx, [rax + FAT32_DIR_SIZE]
    mov [r12 + FS_STAT_SIZE], rbx

    ; Flags
    mov rbx, rax
    call crud_get_entry_flags
    mov [r12 + FS_STAT_FLAGS], eax

    ; Timestamps (zeros)
    mov qword [r12 + FS_STAT_MTIME], 0
    mov qword [r12 + FS_STAT_CTIME], 0
    mov dword [r12 + FS_STAT_RESERVED], 0

    mov eax, 1
    jmp .stat_done

.stat_error:
    xor eax, eax

.stat_done:
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_EXISTS - Check if file exists
; ============================================================================
; Input:  RDI = path
; Output: EAX = 1 if exists, 0 if not
; ============================================================================
crud_exists:
    push rsi

    cmp byte [fat32_mounted], 1
    jne .exists_no

    ; Convert path
    mov rsi, rdi
    lea rdi, [crud_read_temp_name]
    call fat32_convert_name

    ; Find file
    mov eax, [fat32_root_cluster]
    lea rsi, [crud_read_temp_name]
    call fat32_find_file

    test rax, rax
    jz .exists_no

    mov eax, 1
    jmp .exists_done

.exists_no:
    xor eax, eax

.exists_done:
    pop rsi
    ret

; ============================================================================
; INTERNAL: crud_validate_fd - Validate file descriptor
; ============================================================================
; Input:  EDI = fd number
; Output: RAX = fd entry pointer or 0 if invalid
; ============================================================================
crud_validate_fd:
    ; Check range
    cmp edi, FS_MAX_OPEN_FILES
    jge .fd_invalid
    cmp edi, 0
    jl .fd_invalid

    ; Get entry
    mov eax, edi
    imul eax, FS_FD_SIZE
    lea rax, [fs_fd_table + rax]

    ; Check in use
    cmp dword [rax + FS_FD_IN_USE], 0
    je .fd_invalid

    ret

.fd_invalid:
    xor eax, eax
    ret

; ============================================================================
; INTERNAL: crud_open_readonly - Open file for reading
; ============================================================================
; Input:  RDI = path
;         ESI = flags
; Output: EAX = fd or -1
; ============================================================================
crud_open_readonly:
    ; Just call fs_open (already implemented)
    jmp fs_open

; ============================================================================
; INTERNAL: crud_convert_name_83 - Convert 8.3 to readable name
; ============================================================================
; Input:  RBX = FAT32 dir entry
;         RDI = output buffer (32 bytes)
; ============================================================================
crud_convert_name_83:
    push rax
    push rcx
    push rsi
    push rdi

    mov rsi, rbx
    push rdi                        ; save output start

    ; Copy name (8 chars, trim spaces)
    mov ecx, 8
.copy_name:
    lodsb
    cmp al, ' '
    je .name_done
    stosb
    dec ecx
    jnz .copy_name

.name_done:
    ; Check extension
    mov rsi, rbx
    add rsi, 8
    cmp byte [rsi], ' '
    je .no_ext

    ; Add dot
    mov byte [rdi], '.'
    inc rdi

    ; Copy extension
    mov ecx, 3
.copy_ext:
    lodsb
    cmp al, ' '
    je .ext_done
    stosb
    dec ecx
    jnz .copy_ext

.ext_done:
.no_ext:
    ; Add trailing slash for dirs
    test byte [rbx + FAT32_DIR_ATTR], FAT32_ATTR_DIRECTORY
    jz .no_slash
    mov byte [rdi], '/'
    inc rdi
.no_slash:

    ; Null terminate
    mov byte [rdi], 0

    pop rdi
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; ============================================================================
; INTERNAL: crud_get_entry_flags - Convert FAT32 attrs to FS flags
; ============================================================================
; Input:  RBX = FAT32 dir entry
; Output: EAX = FS_ENTRY_* flags
; ============================================================================
crud_get_entry_flags:
    xor eax, eax

    test byte [rbx + FAT32_DIR_ATTR], FAT32_ATTR_DIRECTORY
    jz .not_dir
    or eax, FS_ENTRY_DIR
.not_dir:

    test byte [rbx + FAT32_DIR_ATTR], FAT32_ATTR_HIDDEN
    jz .not_hidden
    or eax, FS_ENTRY_HIDDEN
.not_hidden:

    test byte [rbx + FAT32_DIR_ATTR], FAT32_ATTR_READONLY
    jz .not_readonly
    or eax, FS_ENTRY_READONLY
.not_readonly:

    ret

; ============================================================================
; DATA
; ============================================================================
crud_read_temp_name:    times 12 db 0
