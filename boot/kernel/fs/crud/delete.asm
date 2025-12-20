; ============================================================================
; CRUD/DELETE.ASM - File Deletion Service (SOLID)
; ============================================================================
; Single Responsibility: Delete files and directories from FAT32
;
; Public API:
;   crud_delete(path) -> 1 or 0
;   crud_rename(old_path, new_path) -> 1 or 0
;
; Dependencies: fat32.asm (low-level)
;
; SAFETY: Validates operations to prevent accidental data loss
; ============================================================================

[BITS 64]

; ============================================================================
; CRUD_DELETE - Delete a file or empty directory
; ============================================================================
; Input:  RDI = path (null-terminated)
; Output: EAX = 1 on success, 0 on error
;
; Error conditions:
;   - File not found
;   - Directory not empty
;   - System/read-only file (unless forced)
; ============================================================================
crud_delete:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; r12 = path

    ; --- VALIDATION ---
    cmp byte [fat32_mounted], 1
    jne .delete_error

    ; --- SPLIT PATH INTO PARENT + FILENAME ---
    mov rdi, r12
    call path_split                 ; rax = parent, rdx = filename
    mov r14, rdx                    ; r14 = filename

    ; --- RESOLVE PARENT DIRECTORY ---
    mov rdi, rax                    ; parent path
    call path_resolve
    cmp eax, -1
    je .delete_error
    mov r15d, eax                   ; r15 = parent cluster

    ; --- CONVERT FILENAME ---
    mov rsi, r14
    lea rdi, [crud_delete_temp_name]
    call fat32_convert_name

    ; --- FIND FILE IN PARENT ---
    mov eax, r15d
    lea rsi, [crud_delete_temp_name]
    call fat32_find_file

    test rax, rax
    jz .delete_error                ; Not found

    mov r13, rax                    ; r13 = dir entry
    mov ebx, ecx                    ; ebx = first cluster

    ; --- CHECK IF DIRECTORY ---
    test byte [r13 + FAT32_DIR_ATTR], FAT32_ATTR_DIRECTORY
    jz .delete_file

    ; It's a directory - check if empty
    call crud_is_dir_empty
    test eax, eax
    jz .delete_error                ; Not empty

.delete_file:
    ; --- FREE CLUSTER CHAIN ---
    test ebx, ebx
    jz .skip_free                   ; No clusters to free
    mov eax, ebx
    call fat32_free_chain

.skip_free:
    ; --- MARK ENTRY AS DELETED ---
    mov byte [r13], 0xE5

    ; --- WRITE PARENT DIRECTORY BACK ---
    mov eax, r15d
    mov rsi, fat32_dir_buffer
    call fat32_write_cluster
    jc .delete_error

    mov eax, 1
    jmp .delete_done

.delete_error:
    xor eax, eax

.delete_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_RENAME - Rename a file or directory
; ============================================================================
; Input:  RDI = old path
;         RSI = new path
; Output: EAX = 1 on success, 0 on error
;
; Notes:
;   - Cannot rename across directories (same directory only)
;   - Target must not exist
; ============================================================================
crud_rename:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; r12 = old path
    mov r13, rsi                    ; r13 = new path

    ; --- VALIDATION ---
    cmp byte [fat32_mounted], 1
    jne .rename_error

    ; --- SPLIT OLD PATH ---
    mov rdi, r12
    call path_split                 ; rax = parent, rdx = old filename
    mov r14, rdx                    ; r14 = old filename

    ; --- RESOLVE PARENT DIRECTORY ---
    mov rdi, rax
    call path_resolve
    cmp eax, -1
    je .rename_error
    mov r15d, eax                   ; r15 = parent cluster

    ; --- SPLIT NEW PATH (only need filename) ---
    mov rdi, r13
    call path_split                 ; rdx = new filename

    ; --- CONVERT NEW NAME ---
    mov rsi, rdx
    lea rdi, [crud_rename_new_name]
    call fat32_convert_name

    ; --- CHECK NEW NAME DOESN'T EXIST ---
    mov eax, r15d
    lea rsi, [crud_rename_new_name]
    call fat32_find_file

    test rax, rax
    jnz .rename_error               ; Target exists!

    ; --- CONVERT OLD NAME ---
    mov rsi, r14
    lea rdi, [crud_delete_temp_name]
    call fat32_convert_name

    ; --- FIND OLD FILE ---
    mov eax, r15d
    lea rsi, [crud_delete_temp_name]
    call fat32_find_file

    test rax, rax
    jz .rename_error                ; Source not found

    mov r14, rax                    ; r14 = dir entry

    ; --- UPDATE NAME IN ENTRY ---
    mov rdi, r14
    lea rsi, [crud_rename_new_name]
    mov ecx, 11
    rep movsb

    ; --- WRITE DIRECTORY BACK ---
    mov eax, r15d
    mov rsi, fat32_dir_buffer
    call fat32_write_cluster
    jc .rename_error

    mov eax, 1
    jmp .rename_done

.rename_error:
    xor eax, eax

.rename_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; INTERNAL: crud_is_dir_empty - Check if directory is empty
; ============================================================================
; Input:  EBX = directory first cluster
; Output: EAX = 1 if empty (or only . and ..), 0 if has files
; ============================================================================
crud_is_dir_empty:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Read directory cluster
    mov eax, ebx
    mov rdi, fat32_cluster_buffer
    call fat32_read_cluster
    jc .has_files                   ; Read failed = treat as not empty

    ; Check entries
    mov rbx, fat32_cluster_buffer
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5                      ; entries count

.check_entry:
    test ecx, ecx
    jz .is_empty                    ; Checked all entries

    ; Empty entry = end of directory
    cmp byte [rbx], 0
    je .is_empty

    ; Skip deleted entries
    cmp byte [rbx], 0xE5
    je .next_check

    ; Skip . and .. entries
    cmp byte [rbx], '.'
    jne .has_files

    ; Check if it's just "." or ".."
    cmp byte [rbx + 1], ' '
    je .next_check                  ; "." entry
    cmp byte [rbx + 1], '.'
    jne .has_files
    cmp byte [rbx + 2], ' '
    je .next_check                  ; ".." entry

.has_files:
    xor eax, eax                    ; Not empty
    jmp .empty_done

.next_check:
    add rbx, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jmp .check_entry

.is_empty:
    mov eax, 1

.empty_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
crud_delete_temp_name:  times 12 db 0
crud_rename_new_name:   times 12 db 0
