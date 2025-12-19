; ============================================================================
; CRUD/UPDATE.ASM - File Update/Write Service (SOLID)
; ============================================================================
; Single Responsibility: Write and update files on FAT32
;
; Public API:
;   crud_write(fd, buffer, size) -> bytes_written or -1
;   crud_write_file(path, buffer, size) -> bytes_written or -1
;   crud_seek(fd, offset, whence) -> new_position or -1
;
; Dependencies: fat32.asm (low-level), fs_svc.asm (file descriptors)
;
; SAFETY: All writes go through validation to prevent kernel corruption
; ============================================================================

[BITS 64]

; ============================================================================
; CONSTANTS
; ============================================================================
CRUD_WRITE_SAFE_LBA     equ 1033    ; Minimum safe LBA (past kernel)

; ============================================================================
; CRUD_WRITE - Write to an open file descriptor
; ============================================================================
; Input:  EDI = file descriptor
;         RSI = buffer
;         EDX = size (bytes to write)
; Output: EAX = bytes written, or -1 on error
; ============================================================================
crud_write:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; --- VALIDATE FD ---
    call crud_write_validate_fd
    test rax, rax
    jz .write_error

    mov rbx, rax                    ; rbx = fd entry
    mov r12, rsi                    ; r12 = data buffer
    mov r13d, edx                   ; r13 = bytes to write

    ; --- CHECK WRITE PERMISSION ---
    mov eax, [rbx + FS_FD_FLAGS]
    test eax, FS_O_WRONLY
    jnz .write_ok
    test eax, FS_O_RDWR
    jz .write_error

.write_ok:
    ; --- GET CURRENT CLUSTER ---
    mov r14d, [rbx + FS_FD_CUR_CLUSTER]
    test r14d, r14d
    jnz .have_cluster

    ; No cluster yet - allocate first one
    call fat32_alloc_cluster
    test eax, eax
    jz .write_error
    mov r14d, eax
    mov [rbx + FS_FD_CLUSTER], r14d
    mov [rbx + FS_FD_CUR_CLUSTER], r14d

.have_cluster:
    xor r15d, r15d                  ; r15 = bytes written

.write_loop:
    cmp r15d, r13d
    jge .write_finish

    ; --- SAFETY CHECK ---
    mov eax, r14d
    call crud_validate_cluster_safe
    test eax, eax
    jz .write_error

    ; --- PREPARE CLUSTER BUFFER ---
    ; Read existing cluster content first (for partial writes)
    mov eax, r14d
    mov rdi, fat32_cluster_buffer
    call fat32_read_cluster

    ; --- COPY DATA TO CLUSTER ---
    mov ecx, [fat32_bytes_per_cluster]
    mov eax, r13d
    sub eax, r15d                   ; remaining to write
    cmp ecx, eax
    jle .copy_full
    mov ecx, eax                    ; only copy what's needed

.copy_full:
    ; Copy from source to cluster buffer
    push rcx
    mov rsi, r12
    add rsi, r15                    ; source offset
    mov rdi, fat32_cluster_buffer
    rep movsb
    pop rcx

    ; --- WRITE CLUSTER ---
    mov eax, r14d
    mov rsi, fat32_cluster_buffer
    call fat32_write_cluster
    jc .write_error

    add r15d, ecx

    ; --- NEED MORE CLUSTERS? ---
    cmp r15d, r13d
    jge .write_finish

    ; Allocate next cluster
    push r15
    call fat32_alloc_cluster
    test eax, eax
    pop r15
    jz .write_finish                ; Out of space

    ; Link clusters
    push rax
    mov edx, eax                    ; new cluster
    mov eax, r14d                   ; current cluster
    call fat32_set_cluster
    pop rax

    mov r14d, eax                   ; move to new cluster
    jmp .write_loop

.write_finish:
    ; --- UPDATE FD STATE ---
    mov [rbx + FS_FD_CUR_CLUSTER], r14d
    add [rbx + FS_FD_POS], r15d

    ; Update file size if we wrote past end
    mov eax, [rbx + FS_FD_POS]
    cmp eax, [rbx + FS_FD_FILE_SIZE]
    jle .size_ok
    mov [rbx + FS_FD_FILE_SIZE], eax

.size_ok:
    ; --- UPDATE DIRECTORY ENTRY ---
    mov eax, [rbx + FS_FD_FILE_SIZE]
    mov ecx, [rbx + FS_FD_CLUSTER]
    call crud_update_dir_entry

    mov eax, r15d                   ; return bytes written
    jmp .write_done

.write_error:
    mov eax, -1

.write_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_WRITE_FILE - Write entire file by path
; ============================================================================
; Input:  RDI = path
;         RSI = data buffer
;         EDX = size
; Output: EAX = bytes written or -1
; ============================================================================
crud_write_file:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; path
    mov r13, rsi                    ; data
    mov r14d, edx                   ; size

    ; --- VALIDATION ---
    cmp byte [fat32_mounted], 1
    jne .wf_error

    ; --- CONVERT PATH ---
    mov rsi, r12
    lea rdi, [crud_update_temp_name]
    call fat32_convert_name

    ; --- WRITE VIA FAT32 ---
    lea rsi, [crud_update_temp_name]
    mov rdi, r13
    mov edx, r14d
    call fat32_write_file

    jmp .wf_done

.wf_error:
    mov eax, -1

.wf_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; CRUD_SEEK - Seek within a file
; ============================================================================
; Input:  EDI = file descriptor
;         RSI = offset
;         EDX = whence (FS_SEEK_SET, FS_SEEK_CUR, FS_SEEK_END)
; Output: EAX = new position, or -1 on error
; ============================================================================
crud_seek:
    push rbx

    ; --- VALIDATE FD ---
    call crud_write_validate_fd
    test rax, rax
    jz .seek_error

    mov rbx, rax

    ; --- CALCULATE NEW POSITION ---
    cmp edx, FS_SEEK_SET
    je .seek_set
    cmp edx, FS_SEEK_CUR
    je .seek_cur
    cmp edx, FS_SEEK_END
    je .seek_end
    jmp .seek_error

.seek_set:
    mov eax, esi
    jmp .seek_validate

.seek_cur:
    mov eax, [rbx + FS_FD_POS]
    add eax, esi
    jmp .seek_validate

.seek_end:
    mov eax, [rbx + FS_FD_FILE_SIZE]
    add eax, esi

.seek_validate:
    ; Clamp to valid range [0, file_size]
    test eax, eax
    jns .not_negative
    xor eax, eax
.not_negative:
    cmp eax, [rbx + FS_FD_FILE_SIZE]
    jle .seek_ok
    mov eax, [rbx + FS_FD_FILE_SIZE]

.seek_ok:
    mov [rbx + FS_FD_POS], eax

    ; Reset current cluster to start (seek will recalculate)
    push rax
    mov ecx, [rbx + FS_FD_CLUSTER]
    mov [rbx + FS_FD_CUR_CLUSTER], ecx
    pop rax

    jmp .seek_done

.seek_error:
    mov eax, -1

.seek_done:
    pop rbx
    ret

; ============================================================================
; INTERNAL: crud_write_validate_fd - Validate fd for writing
; ============================================================================
; Input:  EDI = fd number
; Output: RAX = fd entry pointer or 0 if invalid
; ============================================================================
crud_write_validate_fd:
    cmp edi, FS_MAX_OPEN_FILES
    jge .invalid
    cmp edi, 0
    jl .invalid

    mov eax, edi
    imul eax, FS_FD_SIZE
    lea rax, [fs_fd_table + rax]

    cmp dword [rax + FS_FD_IN_USE], 0
    je .invalid

    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; INTERNAL: crud_validate_cluster_safe - Ensure cluster is safe to write
; ============================================================================
; Input:  EAX = cluster number
; Output: EAX = 1 if safe, 0 if not
; ============================================================================
crud_validate_cluster_safe:
    push rbx
    push rcx

    ; Check cluster >= 2
    cmp eax, 2
    jl .unsafe

    ; Check data_lba is valid
    cmp dword [fat32_data_lba], 1024
    jl .unsafe

    ; Calculate LBA
    sub eax, 2
    mov ebx, [fat32_sectors_per_cluster]
    imul eax, ebx
    add eax, [fat32_data_lba]

    ; Verify LBA >= safe threshold
    cmp eax, CRUD_WRITE_SAFE_LBA
    jl .unsafe

    mov eax, 1
    jmp .safe_done

.unsafe:
    xor eax, eax

.safe_done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; INTERNAL: crud_update_dir_entry - Update file size in directory
; ============================================================================
; Input:  EAX = new file size
;         ECX = first cluster
; ============================================================================
crud_update_dir_entry:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    mov r12d, eax                   ; size
    mov r13d, ecx                   ; cluster

    ; Read root directory
    mov eax, [fat32_root_cluster]
    mov rdi, fat32_dir_buffer
    call fat32_read_cluster

    ; Search for entry with matching cluster
    mov rbx, fat32_dir_buffer
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5

.search_entry:
    test ecx, ecx
    jz .update_done

    ; Check if this entry matches our cluster
    movzx eax, word [rbx + FAT32_DIR_CLUSTER_HI]
    shl eax, 16
    or ax, word [rbx + FAT32_DIR_CLUSTER_LO]
    cmp eax, r13d
    je .found_entry

    add rbx, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jmp .search_entry

.found_entry:
    ; Update size
    mov [rbx + FAT32_DIR_SIZE], r12d

    ; Write directory back
    mov eax, [fat32_root_cluster]
    mov rsi, fat32_dir_buffer
    call fat32_write_cluster

.update_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DATA
; ============================================================================
crud_update_temp_name:  times 12 db 0
