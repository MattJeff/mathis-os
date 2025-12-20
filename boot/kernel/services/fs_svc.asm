; ════════════════════════════════════════════════════════════════════════════
; FS_SVC.ASM - Filesystem Service Interface (SOLID)
; ════════════════════════════════════════════════════════════════════════════
; Abstract filesystem interface - implementations (FAT32, etc) register here.
; All filesystem operations go through this service - no direct driver calls.
;
; Architecture (SOLID):
;   - fs_svc.asm: Service interface + vtable (this file)
;   - fs/crud/create.asm: File/directory creation
;   - fs/crud/read.asm: File/directory reading
;   - fs/crud/update.asm: File writing and seeking
;   - fs/crud/delete.asm: File/directory deletion and rename
;
; Usage:
;   mov edi, SVC_FS
;   call get_service
;   ; rax = fs_vtable
;   mov rdi, path
;   call [rax + FS_READDIR]
;
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; FS SERVICE V-TABLE OFFSETS
; ════════════════════════════════════════════════════════════════════════════
FS_MOUNT        equ 0       ; mount() -> bool
FS_UNMOUNT      equ 8       ; unmount() -> void
FS_OPEN         equ 16      ; open(path, flags) -> fd
FS_CLOSE        equ 24      ; close(fd) -> void
FS_READ         equ 32      ; read(fd, buf, size) -> bytes_read
FS_WRITE        equ 40      ; write(fd, buf, size) -> bytes_written
FS_SEEK         equ 48      ; seek(fd, offset, whence) -> new_pos
FS_READDIR      equ 56      ; readdir(path, buf, max_entries) -> count
FS_STAT         equ 64      ; stat(path, statbuf) -> bool
FS_MKDIR        equ 72      ; mkdir(path) -> bool
FS_DELETE       equ 80      ; delete(path) -> bool
FS_RENAME       equ 88      ; rename(old, new) -> bool
FS_EXISTS       equ 96      ; exists(path) -> bool

; ════════════════════════════════════════════════════════════════════════════
; FILE OPEN FLAGS
; ════════════════════════════════════════════════════════════════════════════
FS_O_RDONLY     equ 0x00    ; Read only
FS_O_WRONLY     equ 0x01    ; Write only
FS_O_RDWR       equ 0x02    ; Read/Write
FS_O_CREATE     equ 0x04    ; Create if not exists
FS_O_TRUNC      equ 0x08    ; Truncate if exists
FS_O_APPEND     equ 0x10    ; Append mode

; ════════════════════════════════════════════════════════════════════════════
; SEEK WHENCE VALUES
; ════════════════════════════════════════════════════════════════════════════
FS_SEEK_SET     equ 0       ; From beginning
FS_SEEK_CUR     equ 1       ; From current position
FS_SEEK_END     equ 2       ; From end

; ════════════════════════════════════════════════════════════════════════════
; DIRECTORY ENTRY STRUCTURE (returned by readdir)
; ════════════════════════════════════════════════════════════════════════════
; Total: 64 bytes per entry
;
; Offset  Size  Field
; ------  ----  -----
;   0      32   name (null-terminated, max 31 chars)
;  32       4   size (bytes, 0 for directories)
;  36       4   flags (FS_ENTRY_*)
;  40       8   modified_time (unix timestamp or custom)
;  48       8   created_time
;  56       4   cluster (internal use)
;  60       4   reserved
;
FS_DIRENT_SIZE      equ 64
FS_DIRENT_NAME      equ 0
FS_DIRENT_SIZE_OFF  equ 32
FS_DIRENT_FLAGS     equ 36
FS_DIRENT_MTIME     equ 40
FS_DIRENT_CTIME     equ 48
FS_DIRENT_CLUSTER   equ 56
FS_DIRENT_RESERVED  equ 60

; ════════════════════════════════════════════════════════════════════════════
; ENTRY FLAGS
; ════════════════════════════════════════════════════════════════════════════
FS_ENTRY_FILE       equ 0x00
FS_ENTRY_DIR        equ 0x01
FS_ENTRY_HIDDEN     equ 0x02
FS_ENTRY_SYSTEM     equ 0x04
FS_ENTRY_READONLY   equ 0x08

; ════════════════════════════════════════════════════════════════════════════
; STAT STRUCTURE (returned by stat)
; ════════════════════════════════════════════════════════════════════════════
; Total: 32 bytes
;
FS_STAT_SIZE        equ 0       ; File size (8 bytes)
FS_STAT_FLAGS       equ 8       ; Flags (4 bytes)
FS_STAT_MTIME       equ 12      ; Modified time (8 bytes)
FS_STAT_CTIME       equ 20      ; Created time (8 bytes)
FS_STAT_RESERVED    equ 28      ; Reserved (4 bytes)
FS_STAT_STRUCT_SIZE equ 32

; ════════════════════════════════════════════════════════════════════════════
; FILE DESCRIPTOR TABLE
; ════════════════════════════════════════════════════════════════════════════
FS_MAX_OPEN_FILES   equ 16

; File descriptor entry (32 bytes)
FS_FD_SIZE          equ 32
FS_FD_FLAGS         equ 0       ; Open flags (4 bytes)
FS_FD_POS           equ 4       ; Current position (8 bytes)
FS_FD_FILE_SIZE     equ 12      ; File size (4 bytes)
FS_FD_CLUSTER       equ 16      ; Start cluster (4 bytes)
FS_FD_CUR_CLUSTER   equ 20      ; Current cluster (4 bytes)
FS_FD_CUR_OFFSET    equ 24      ; Offset in current cluster (4 bytes)
FS_FD_IN_USE        equ 28      ; 1 if in use (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; FS SERVICE V-TABLE (points to FAT32 implementation)
; ════════════════════════════════════════════════════════════════════════════
fs_svc_vtable:
    dq fs_mount             ; FS_MOUNT
    dq fs_unmount           ; FS_UNMOUNT
    dq fs_open              ; FS_OPEN
    dq fs_close             ; FS_CLOSE
    dq fs_read              ; FS_READ
    dq fs_write             ; FS_WRITE
    dq fs_seek              ; FS_SEEK
    dq fs_readdir           ; FS_READDIR
    dq fs_stat              ; FS_STAT
    dq fs_mkdir             ; FS_MKDIR
    dq fs_delete            ; FS_DELETE
    dq fs_rename            ; FS_RENAME
    dq fs_exists            ; FS_EXISTS

; ════════════════════════════════════════════════════════════════════════════
; FS_SVC_INIT - Register filesystem service
; Call this after registry_init and fat32_init
; ════════════════════════════════════════════════════════════════════════════
fs_svc_init:
    push rdi
    push rsi

    ; Initialize file descriptor table
    call fs_init_fd_table

    ; Register with service registry
    mov edi, SVC_FS
    lea rsi, [fs_svc_vtable]
    call register_service

    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_INIT_FD_TABLE - Clear file descriptor table
; ════════════════════════════════════════════════════════════════════════════
fs_init_fd_table:
    push rax
    push rcx
    push rdi

    lea rdi, [fs_fd_table]
    mov ecx, FS_MAX_OPEN_FILES * FS_FD_SIZE
    xor eax, eax
    rep stosb

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_MOUNT - Mount the filesystem
; Output: EAX = 1 on success, 0 on failure
; ════════════════════════════════════════════════════════════════════════════
fs_mount:
    ; Check if FAT32 is already mounted
    cmp byte [fat32_mounted], 1
    je .already_mounted

    ; Initialize FAT32
    call fat32_init
    jc .mount_failed

    mov eax, 1
    ret

.already_mounted:
    mov eax, 1
    ret

.mount_failed:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_UNMOUNT - Unmount the filesystem
; ════════════════════════════════════════════════════════════════════════════
fs_unmount:
    ; Close all open files
    call fs_close_all

    ; Clear mounted flag
    mov byte [fat32_mounted], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_CLOSE_ALL - Close all open file descriptors
; ════════════════════════════════════════════════════════════════════════════
fs_close_all:
    push rax
    push rcx
    push rdi

    lea rdi, [fs_fd_table]
    mov ecx, FS_MAX_OPEN_FILES

.close_loop:
    mov dword [rdi + FS_FD_IN_USE], 0
    add rdi, FS_FD_SIZE
    dec ecx
    jnz .close_loop

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_OPEN - Open a file
; Input:  RDI = path (null-terminated)
;         ESI = flags (FS_O_*)
; Output: EAX = file descriptor (0-15) or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_open:
    push rbx
    push rcx
    push rdx
    push r12
    push r13

    mov r12, rdi                    ; Save path
    mov r13d, esi                   ; Save flags

    ; Check if mounted
    cmp byte [fat32_mounted], 1
    jne .open_error

    ; Find free file descriptor
    lea rbx, [fs_fd_table]
    xor ecx, ecx

.find_fd:
    cmp ecx, FS_MAX_OPEN_FILES
    jge .open_error

    cmp dword [rbx + FS_FD_IN_USE], 0
    je .found_fd

    add rbx, FS_FD_SIZE
    inc ecx
    jmp .find_fd

.found_fd:
    ; ecx = file descriptor number
    ; rbx = pointer to fd entry
    push rcx

    ; Convert path to FAT32 8.3 format
    mov rsi, r12
    lea rdi, [fs_temp_name]
    call fat32_convert_name

    ; Find file in root directory
    ; fat32_find_file: EAX = dir cluster, RSI = filename
    ; Returns: RAX = entry ptr, ECX = file cluster
    mov eax, [fat32_root_cluster]
    lea rsi, [fs_temp_name]
    call fat32_find_file
    test rax, rax
    jz .open_not_found

    ; rax = dir entry pointer, ecx = cluster
    ; Get file size from entry
    mov edx, [rax + FAT32_DIR_SIZE]

    pop rax                         ; Restore fd number (was in ecx, now in rax)
    push rax

    ; Fill in file descriptor
    mov dword [rbx + FS_FD_FLAGS], r13d
    mov qword [rbx + FS_FD_POS], 0
    mov [rbx + FS_FD_FILE_SIZE], edx
    mov [rbx + FS_FD_CLUSTER], ecx      ; Start cluster from find_file
    mov [rbx + FS_FD_CUR_CLUSTER], ecx
    mov dword [rbx + FS_FD_CUR_OFFSET], 0
    mov dword [rbx + FS_FD_IN_USE], 1

    pop rax                         ; Return fd number
    jmp .open_done

.open_not_found:
    ; Check if CREATE flag is set
    test r13d, FS_O_CREATE
    jz .open_error_pop

    ; TODO: Create file
    ; For now, fail
    jmp .open_error_pop

.open_error_pop:
    pop rcx
.open_error:
    mov eax, -1

.open_done:
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_CLOSE - Close a file descriptor
; Input:  EDI = file descriptor
; ════════════════════════════════════════════════════════════════════════════
fs_close:
    push rax
    push rbx

    ; Validate fd
    cmp edi, FS_MAX_OPEN_FILES
    jge .close_done

    cmp edi, 0
    jl .close_done

    ; Get fd entry
    mov eax, edi
    imul eax, FS_FD_SIZE
    lea rbx, [fs_fd_table + rax]

    ; Mark as not in use
    mov dword [rbx + FS_FD_IN_USE], 0

.close_done:
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_READ - Read from a file
; Input:  EDI = file descriptor
;         RSI = buffer
;         EDX = size (bytes to read)
; Output: EAX = bytes read, or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_read:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; Validate fd
    cmp edi, FS_MAX_OPEN_FILES
    jge .read_error
    cmp edi, 0
    jl .read_error

    ; Get fd entry
    mov eax, edi
    imul eax, FS_FD_SIZE
    lea rbx, [fs_fd_table + rax]

    ; Check if in use
    cmp dword [rbx + FS_FD_IN_USE], 0
    je .read_error

    mov r12, rsi                    ; r12 = buffer
    mov r13d, edx                   ; r13 = bytes to read
    xor r14d, r14d                  ; r14 = bytes read so far

    ; Check if at EOF
    mov eax, [rbx + FS_FD_POS]
    cmp eax, [rbx + FS_FD_FILE_SIZE]
    jge .read_eof

    ; Limit read to remaining file size
    mov ecx, [rbx + FS_FD_FILE_SIZE]
    sub ecx, eax                    ; ecx = remaining bytes
    cmp r13d, ecx
    jle .size_ok
    mov r13d, ecx                   ; Clamp to remaining

.size_ok:
    ; Read cluster chain starting from current cluster
    mov r15d, [rbx + FS_FD_CUR_CLUSTER]

.read_loop:
    ; Check if we've read enough
    cmp r14d, r13d
    jge .read_complete

    ; Read current cluster
    mov eax, r15d
    mov rdi, r12                    ; Current buffer position
    call fat32_read_cluster

    ; How many bytes did we get from this cluster?
    mov ecx, [fat32_bytes_per_cluster]

    ; Check if this is more than we need
    mov eax, r13d
    sub eax, r14d                   ; Remaining bytes to read
    cmp ecx, eax
    jle .use_full_cluster
    mov ecx, eax                    ; Only take what we need

.use_full_cluster:
    add r14d, ecx                   ; Add to bytes read
    add r12, rcx                    ; Advance buffer

    ; Get next cluster
    mov eax, r15d
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .read_complete              ; End of chain
    mov r15d, eax
    jmp .read_loop

.read_complete:
    ; Update position and current cluster in fd
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

; ════════════════════════════════════════════════════════════════════════════
; FS_WRITE - Write to a file
; Input:  EDI = file descriptor
;         RSI = buffer
;         EDX = size (bytes to write)
; Output: EAX = bytes written, or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_write:
    ; Delegate to CRUD module
    jmp crud_write

; ════════════════════════════════════════════════════════════════════════════
; FS_SEEK - Seek in a file
; Input:  EDI = file descriptor
;         RSI = offset
;         EDX = whence (FS_SEEK_*)
; Output: EAX = new position, or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_seek:
    push rbx

    ; Validate fd
    cmp edi, FS_MAX_OPEN_FILES
    jge .seek_error
    cmp edi, 0
    jl .seek_error

    ; Get fd entry
    mov eax, edi
    imul eax, FS_FD_SIZE
    lea rbx, [fs_fd_table + rax]

    ; Check if in use
    cmp dword [rbx + FS_FD_IN_USE], 0
    je .seek_error

    ; Calculate new position based on whence
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
    ; Clamp to valid range
    test eax, eax
    jns .not_negative
    xor eax, eax                    ; Clamp to 0
.not_negative:
    cmp eax, [rbx + FS_FD_FILE_SIZE]
    jle .seek_ok
    mov eax, [rbx + FS_FD_FILE_SIZE] ; Clamp to file size

.seek_ok:
    mov [rbx + FS_FD_POS], eax
    jmp .seek_done

.seek_error:
    mov eax, -1

.seek_done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_READDIR - Read directory entries
; Input:  RDI = path (null-terminated, "/" for root)
;         RSI = buffer (array of FS_DIRENT_SIZE entries)
;         EDX = max_entries
; Output: EAX = number of entries read, or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_readdir:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; Check if mounted
    cmp byte [fat32_mounted], 1
    jne .readdir_error

    mov r12, rdi                    ; r12 = path
    mov r13, rsi                    ; r13 = output buffer
    mov r14d, edx                   ; r14 = max entries
    xor r15d, r15d                  ; r15 = entry count

    ; Resolve path to cluster
    mov rdi, r12
    call path_resolve
    cmp eax, -1
    je .readdir_error

    ; Read directory entries from resolved cluster
    mov rdi, fat32_dir_buffer           ; Use 4KB buffer (not 512B sector buffer!)
    call fat32_read_cluster
    jc .readdir_error                   ; CF set = error

    ; Parse directory entries
    mov rbx, fat32_dir_buffer
    mov ecx, [fat32_sectors_per_cluster]
    imul ecx, 16                    ; 16 entries per sector (512/32)

.parse_entry:
    ; Check if we've reached max entries
    cmp r15d, r14d
    jge .readdir_done

    ; Check for end of directory
    cmp byte [rbx], 0
    je .readdir_done

    ; Check for deleted entry
    cmp byte [rbx], 0xE5
    je .next_entry

    ; Check for LFN entry (skip)
    mov al, [rbx + FAT32_DIR_ATTR]
    cmp al, FAT32_ATTR_LFN
    je .next_entry

    ; Check for volume label (skip)
    test al, FAT32_ATTR_VOLUME_ID
    jnz .next_entry

    ; Valid entry - copy to output buffer
    push rcx
    push rbx

    ; Calculate output position
    mov eax, r15d
    imul eax, FS_DIRENT_SIZE
    lea rdi, [r13 + rax]

    ; Copy and convert name (8.3 to readable)
    call fs_convert_83_to_name

    ; Copy size
    mov eax, [rbx + FAT32_DIR_SIZE]
    mov [rdi + FS_DIRENT_SIZE_OFF], eax

    ; Set flags
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
    mov [rdi + FS_DIRENT_FLAGS], eax

    ; Get cluster
    movzx eax, word [rbx + FAT32_DIR_CLUSTER_HI]
    shl eax, 16
    or ax, word [rbx + FAT32_DIR_CLUSTER_LO]
    mov [rdi + FS_DIRENT_CLUSTER], eax

    ; TODO: Convert FAT32 time/date to timestamp
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

    ; TODO: Follow cluster chain for more entries

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

; ════════════════════════════════════════════════════════════════════════════
; FS_CONVERT_83_TO_NAME - Convert 8.3 FAT name to readable string
; Input:  RBX = FAT32 directory entry
;         RDI = output buffer (32 bytes)
; ════════════════════════════════════════════════════════════════════════════
fs_convert_83_to_name:
    push rax
    push rcx
    push rsi
    push rdi

    mov rsi, rbx                    ; Source = FAT entry
    push rdi                        ; Save output start

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
    ; Check if there's an extension
    mov rsi, rbx
    add rsi, 8                      ; Point to extension
    cmp byte [rsi], ' '
    je .no_ext

    ; Add dot
    mov byte [rdi], '.'
    inc rdi

    ; Copy extension (3 chars, trim spaces)
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
    ; Add trailing slash for directories
    test byte [rbx + FAT32_DIR_ATTR], FAT32_ATTR_DIRECTORY
    jz .not_dir_suffix
    mov byte [rdi], '/'
    inc rdi
.not_dir_suffix:

    ; Null terminate
    mov byte [rdi], 0

    pop rdi
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_STAT - Get file information
; Input:  RDI = path
;         RSI = stat buffer (FS_STAT_STRUCT_SIZE bytes)
; Output: EAX = 1 on success, 0 if not found
; ════════════════════════════════════════════════════════════════════════════
fs_stat:
    push rbx
    push rcx
    push r12

    mov r12, rsi                    ; Save stat buffer

    ; Check if mounted
    cmp byte [fat32_mounted], 1
    jne .stat_error

    ; Convert path to 8.3
    mov rsi, rdi
    lea rdi, [fs_temp_name]
    call fat32_convert_name

    ; Find file
    lea rsi, [fs_temp_name]
    call fat32_find_file
    test eax, eax
    jz .stat_error

    ; eax = cluster, edx = size, ecx = attributes
    ; Fill stat buffer
    mov [r12 + FS_STAT_SIZE], rdx

    ; Convert attributes to flags
    xor ebx, ebx
    test ecx, FAT32_ATTR_DIRECTORY
    jz .not_dir_stat
    or ebx, FS_ENTRY_DIR
.not_dir_stat:
    test ecx, FAT32_ATTR_HIDDEN
    jz .not_hidden_stat
    or ebx, FS_ENTRY_HIDDEN
.not_hidden_stat:
    test ecx, FAT32_ATTR_READONLY
    jz .not_readonly_stat
    or ebx, FS_ENTRY_READONLY
.not_readonly_stat:
    mov [r12 + FS_STAT_FLAGS], ebx

    ; TODO: Time conversion
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

; ════════════════════════════════════════════════════════════════════════════
; FS_MKDIR - Create a directory
; Input:  RDI = path
; Output: EAX = 1 on success, 0 on error
; ════════════════════════════════════════════════════════════════════════════
fs_mkdir:
    push rbx
    push r12

    ; Clean path (strip trailing /)
    mov r12, rdi
    call fs_clean_path              ; Result in fs_path_buffer

    ; Call CRUD
    lea rdi, [fs_path_buffer]
    call crud_create_dir
    mov ebx, eax                    ; Save result

    ; Dispatch event if successful
    test eax, eax
    jz .mkdir_done
    mov edi, FS_EVT_MKDIR
    lea rsi, [fs_path_buffer]
    call fs_dispatch_event

.mkdir_done:
    mov eax, ebx
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_DELETE - Delete a file or empty directory
; Input:  RDI = path
; Output: EAX = 1 on success, 0 on error
; ════════════════════════════════════════════════════════════════════════════
fs_delete:
    push rbx
    push r12

    ; Clean path (strip trailing /)
    mov r12, rdi
    call fs_clean_path              ; Result in fs_path_buffer

    ; Call CRUD
    lea rdi, [fs_path_buffer]
    call crud_delete
    mov ebx, eax                    ; Save result

    ; Dispatch event if successful
    test eax, eax
    jz .delete_done
    mov edi, FS_EVT_DELETE
    lea rsi, [fs_path_buffer]
    call fs_dispatch_event

.delete_done:
    mov eax, ebx
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_RENAME - Rename a file or directory
; Input:  RDI = old path
;         RSI = new path
; Output: EAX = 1 on success, 0 on error
; ════════════════════════════════════════════════════════════════════════════
fs_rename:
    push rbx
    push r12
    push r13

    mov r12, rdi                    ; old path
    mov r13, rsi                    ; new path

    ; Clean old path
    mov rdi, r12
    call fs_clean_path
    ; Copy to secondary buffer
    lea rsi, [fs_path_buffer]
    lea rdi, [fs_path_buffer2]
    call fs_strcpy

    ; Clean new path
    mov rdi, r13
    call fs_clean_path

    ; Call CRUD (old in rdi, new in rsi)
    lea rdi, [fs_path_buffer2]
    lea rsi, [fs_path_buffer]
    call crud_rename
    mov ebx, eax

    ; Dispatch event if successful
    test eax, eax
    jz .rename_done
    mov edi, FS_EVT_RENAME
    lea rsi, [fs_path_buffer]
    call fs_dispatch_event

.rename_done:
    mov eax, ebx
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_CLEAN_PATH - Copy path to buffer and strip trailing /
; Input:  RDI = source path
; Output: fs_path_buffer contains cleaned path
; ════════════════════════════════════════════════════════════════════════════
fs_clean_path:
    push rax
    push rcx
    push rdi
    push rsi

    mov rsi, rdi                    ; source
    lea rdi, [fs_path_buffer]       ; dest
    mov ecx, 30                     ; max chars

.copy_loop:
    lodsb
    test al, al
    jz .copy_done
    stosb
    dec ecx
    jnz .copy_loop

.copy_done:
    mov byte [rdi], 0               ; null terminate

    ; Strip trailing /
    lea rdi, [fs_path_buffer]
.find_end:
    cmp byte [rdi], 0
    je .at_end
    inc rdi
    jmp .find_end

.at_end:
    lea rax, [fs_path_buffer]
    cmp rdi, rax                    ; empty string?
    je .clean_done
    dec rdi                         ; point to last char
    cmp byte [rdi], '/'
    jne .clean_done
    mov byte [rdi], 0               ; remove trailing /

.clean_done:
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_STRCPY - Copy null-terminated string
; Input:  RSI = source, RDI = dest
; ════════════════════════════════════════════════════════════════════════════
fs_strcpy:
    push rax
.strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz .strcpy_loop
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EXISTS - Check if file/directory exists
; Input:  RDI = path
; Output: EAX = 1 if exists, 0 if not
; ════════════════════════════════════════════════════════════════════════════
fs_exists:
    push rsi

    ; Check if mounted
    cmp byte [fat32_mounted], 1
    jne .exists_no

    ; Convert path to 8.3
    mov rsi, rdi
    lea rdi, [fs_temp_name]
    call fat32_convert_name

    ; Find file
    lea rsi, [fs_temp_name]
    call fat32_find_file
    test eax, eax
    jz .exists_no

    mov eax, 1
    jmp .exists_done

.exists_no:
    xor eax, eax

.exists_done:
    pop rsi
    ret

; ════════════════════════════════════════════════════════════════════════════
; HELPER: Read full file content
; Input:  RDI = path
;         RSI = buffer
;         EDX = buffer size
; Output: EAX = bytes read, or -1 on error
; ════════════════════════════════════════════════════════════════════════════
fs_read_file:
    push rbx
    push r12
    push r13

    mov r12, rsi                    ; buffer
    mov r13d, edx                   ; max size

    ; Open file
    mov esi, FS_O_RDONLY
    call fs_open
    cmp eax, -1
    je .rf_error

    mov ebx, eax                    ; Save fd

    ; Read content
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call fs_read
    push rax                        ; Save bytes read

    ; Close file
    mov edi, ebx
    call fs_close

    pop rax                         ; Return bytes read
    jmp .rf_done

.rf_error:
    mov eax, -1

.rf_done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
align 8
fs_fd_table:        times (FS_MAX_OPEN_FILES * FS_FD_SIZE) db 0
fs_temp_name:       times 12 db 0       ; 8.3 name buffer
fs_temp_path:       times 256 db 0      ; Path buffer
fs_path_buffer:     times 32 db 0       ; Clean path buffer (strip /)
fs_path_buffer2:    times 32 db 0       ; Second buffer for rename

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE EVENTS SUBSYSTEM
; ════════════════════════════════════════════════════════════════════════════
%include "services/fs_events.asm"
