; ============================================================================
; CRUD/CREATE.ASM - File Creation Service (SOLID)
; ============================================================================
; Single Responsibility: Create files and directories on FAT32
;
; Public API:
;   crud_create_file(path, flags) -> fd or -1
;   crud_create_dir(path) -> 1 or 0
;
; Dependencies: fat32.asm (low-level), fs_svc.asm (file descriptors)
; ============================================================================

[BITS 64]

; ============================================================================
; CONSTANTS
; ============================================================================
CRUD_CREATE_OK          equ 1
CRUD_CREATE_ERR         equ 0
CRUD_CREATE_EXISTS      equ -2      ; File already exists

; ============================================================================
; CRUD_CREATE_FILE - Create a new file
; ============================================================================
; Input:  RDI = path (null-terminated)
;         ESI = flags (FS_O_CREATE, FS_O_TRUNC, etc.)
; Output: EAX = file descriptor (0-15) or -1 on error
;
; Behavior:
;   - If file exists and FS_O_TRUNC: truncate and return fd
;   - If file exists and no FS_O_TRUNC: return existing fd
;   - If file doesn't exist and FS_O_CREATE: create and return fd
;   - If file doesn't exist and no FS_O_CREATE: return -1
; ============================================================================
crud_create_file:
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; r12 = path
    mov r13d, esi                   ; r13 = flags

    ; --- VALIDATION ---
    call crud_validate_mounted
    test eax, eax
    jz .create_error

    ; --- CONVERT PATH TO 8.3 ---
    mov rsi, r12
    lea rdi, [crud_temp_name]
    call fat32_convert_name

    ; --- CHECK IF FILE EXISTS ---
    mov eax, [fat32_root_cluster]
    lea rsi, [crud_temp_name]
    call fat32_find_file

    test rax, rax
    jnz .file_exists

    ; --- FILE DOES NOT EXIST ---
    test r13d, FS_O_CREATE
    jz .create_error                ; No CREATE flag = error

    ; Create new file
    call crud_do_create_file
    test eax, eax
    jz .create_error

    mov r14d, eax                   ; r14 = new cluster

    ; Allocate file descriptor
    mov rdi, r12
    mov esi, r13d
    xor edx, edx                    ; size = 0 (new file)
    mov ecx, r14d                   ; cluster
    call crud_alloc_fd
    jmp .create_done

.file_exists:
    ; File exists - check TRUNC flag
    mov r14d, ecx                   ; r14 = existing cluster
    mov ebx, [rax + FAT32_DIR_SIZE] ; ebx = existing size

    test r13d, FS_O_TRUNC
    jz .open_existing

    ; Truncate file
    mov eax, r14d
    call crud_do_truncate
    xor ebx, ebx                    ; size = 0 after truncate

.open_existing:
    ; Allocate file descriptor for existing file
    mov rdi, r12
    mov esi, r13d
    mov edx, ebx                    ; size
    mov ecx, r14d                   ; cluster
    call crud_alloc_fd
    jmp .create_done

.create_error:
    mov eax, -1

.create_done:
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; CRUD_CREATE_DIR - Create a new directory
; ============================================================================
; Input:  RDI = path (null-terminated)
; Output: EAX = 1 on success, 0 on error
; ============================================================================
crud_create_dir:
    push rbx
    push rcx
    push rdx
    push r12

    mov r12, rdi                    ; r12 = path

    ; --- VALIDATION ---
    call crud_validate_mounted
    test eax, eax
    jz .mkdir_error

    ; --- CONVERT PATH TO 8.3 ---
    mov rsi, r12
    lea rdi, [crud_temp_name]
    call fat32_convert_name

    ; --- CHECK IF ALREADY EXISTS ---
    mov eax, [fat32_root_cluster]
    lea rsi, [crud_temp_name]
    call fat32_find_file

    test rax, rax
    jnz .mkdir_error                ; Already exists

    ; --- CREATE DIRECTORY ---
    lea rsi, [crud_temp_name]
    mov eax, [fat32_root_cluster]
    call fat32_create_dir

    test eax, eax
    jz .mkdir_error

    mov eax, CRUD_CREATE_OK
    jmp .mkdir_done

.mkdir_error:
    mov eax, CRUD_CREATE_ERR

.mkdir_done:
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; INTERNAL: crud_do_create_file - Low-level file creation
; ============================================================================
; Input:  crud_temp_name = 8.3 filename
; Output: EAX = first cluster or 0 on error
; ============================================================================
crud_do_create_file:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Allocate cluster for file
    call fat32_alloc_cluster
    test eax, eax
    jz .do_create_error

    mov ebx, eax                    ; ebx = new cluster

    ; Read directory
    mov eax, [fat32_root_cluster]
    mov rdi, fat32_dir_buffer
    call fat32_read_cluster

    ; Find free entry
    mov rdi, fat32_dir_buffer
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5                      ; entries count

.find_free:
    cmp byte [rdi], 0               ; Empty?
    je .found_free
    cmp byte [rdi], 0xE5            ; Deleted?
    je .found_free

    add rdi, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jnz .find_free

    ; No free entry - free the cluster and fail
    mov eax, ebx
    xor edx, edx
    call fat32_set_cluster
    xor eax, eax
    jmp .do_create_done

.found_free:
    ; Fill directory entry
    push rdi

    ; Copy filename
    lea rsi, [crud_temp_name]
    mov ecx, 11
    rep movsb

    pop rdi

    ; Set attributes
    mov byte [rdi + FAT32_DIR_ATTR], FAT32_ATTR_ARCHIVE

    ; Clear reserved
    mov byte [rdi + 12], 0
    mov byte [rdi + 13], 0

    ; Timestamps (zeros for now)
    xor eax, eax
    mov [rdi + 14], ax              ; Create time
    mov [rdi + 16], ax              ; Create date
    mov [rdi + 18], ax              ; Access date
    mov [rdi + 22], ax              ; Modify time
    mov [rdi + 24], ax              ; Modify date

    ; Set cluster
    mov eax, ebx
    mov [rdi + FAT32_DIR_CLUSTER_LO], ax
    shr eax, 16
    mov [rdi + FAT32_DIR_CLUSTER_HI], ax

    ; Set size = 0
    mov dword [rdi + FAT32_DIR_SIZE], 0

    ; Write directory back
    mov eax, [fat32_root_cluster]
    mov rsi, fat32_dir_buffer
    call fat32_write_cluster
    jc .do_create_error

    mov eax, ebx                    ; Return cluster
    jmp .do_create_done

.do_create_error:
    xor eax, eax

.do_create_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; INTERNAL: crud_do_truncate - Truncate file to zero length
; ============================================================================
; Input:  EAX = first cluster
; Output: CF set on error
; ============================================================================
crud_do_truncate:
    push rax
    push rbx
    push rcx
    push rdx

    mov ebx, eax                    ; Save first cluster

    ; Free all clusters except first
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .trunc_mark_end

    ; Free the chain starting from second cluster
    call fat32_free_chain

.trunc_mark_end:
    ; Mark first cluster as end
    mov eax, ebx
    mov edx, FAT32_END_CLUSTER
    call fat32_set_cluster

    clc
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; INTERNAL: crud_validate_mounted - Check FAT32 is ready
; ============================================================================
; Output: EAX = 1 if mounted, 0 if not
; ============================================================================
crud_validate_mounted:
    xor eax, eax
    cmp byte [fat32_mounted], 1
    jne .not_mounted
    mov eax, 1
.not_mounted:
    ret

; ============================================================================
; INTERNAL: crud_alloc_fd - Allocate and initialize file descriptor
; ============================================================================
; Input:  RDI = path (for reference)
;         ESI = flags
;         EDX = file size
;         ECX = first cluster
; Output: EAX = fd number or -1
; ============================================================================
crud_alloc_fd:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, esi                   ; flags
    mov r13d, edx                   ; size
    mov r14d, ecx                   ; cluster

    ; Find free fd slot
    lea rbx, [fs_fd_table]
    xor ecx, ecx

.find_fd:
    cmp ecx, FS_MAX_OPEN_FILES
    jge .alloc_error

    cmp dword [rbx + FS_FD_IN_USE], 0
    je .found_fd

    add rbx, FS_FD_SIZE
    inc ecx
    jmp .find_fd

.found_fd:
    ; Fill descriptor
    mov [rbx + FS_FD_FLAGS], r12d
    mov qword [rbx + FS_FD_POS], 0
    mov [rbx + FS_FD_FILE_SIZE], r13d
    mov [rbx + FS_FD_CLUSTER], r14d
    mov [rbx + FS_FD_CUR_CLUSTER], r14d
    mov dword [rbx + FS_FD_CUR_OFFSET], 0
    mov dword [rbx + FS_FD_IN_USE], 1

    mov eax, ecx                    ; Return fd number
    jmp .alloc_done

.alloc_error:
    mov eax, -1

.alloc_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
crud_temp_name:     times 12 db 0
