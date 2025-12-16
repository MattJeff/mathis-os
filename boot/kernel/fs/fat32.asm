; ════════════════════════════════════════════════════════════════════════════
; FAT32.ASM - FAT32 Filesystem Driver
; Full read support for FAT32 volumes (USB, SD card, HDD)
; ════════════════════════════════════════════════════════════════════════════
;
; FAT32 Structure:
;   - Boot Sector (BPB - BIOS Parameter Block)
;   - Reserved Sectors
;   - FAT1 (File Allocation Table)
;   - FAT2 (backup, optional)
;   - Data Region (clusters)
;
; Directory Entry: 32 bytes
;   +0:  Name (8 bytes, space padded)
;   +8:  Extension (3 bytes)
;   +11: Attributes (1 byte)
;   +12: Reserved
;   +13: Created time (tenths)
;   +14: Created time
;   +16: Created date
;   +18: Accessed date
;   +20: Cluster high (2 bytes)
;   +22: Modified time
;   +24: Modified date
;   +26: Cluster low (2 bytes)
;   +28: File size (4 bytes)
;
; ════════════════════════════════════════════════════════════════════════════

; FAT32 Constants
FAT32_SECTOR_SIZE       equ 512
FAT32_DIR_ENTRY_SIZE    equ 32

; Directory entry offsets
FAT32_DIR_NAME          equ 0
FAT32_DIR_EXT           equ 8
FAT32_DIR_ATTR          equ 11
FAT32_DIR_CLUSTER_HI    equ 20
FAT32_DIR_CLUSTER_LO    equ 26
FAT32_DIR_SIZE          equ 28

; File attributes
FAT32_ATTR_READONLY     equ 0x01
FAT32_ATTR_HIDDEN       equ 0x02
FAT32_ATTR_SYSTEM       equ 0x04
FAT32_ATTR_VOLUME_ID    equ 0x08
FAT32_ATTR_DIRECTORY    equ 0x10
FAT32_ATTR_ARCHIVE      equ 0x20
FAT32_ATTR_LFN          equ 0x0F    ; Long filename entry

; FAT entry special values
FAT32_FREE_CLUSTER      equ 0x00000000
FAT32_BAD_CLUSTER       equ 0x0FFFFFF7
FAT32_END_CLUSTER       equ 0x0FFFFFF8  ; >= this means end of chain

; Partition types
PART_TYPE_FAT32         equ 0x0B
PART_TYPE_FAT32_LBA     equ 0x0C

; ════════════════════════════════════════════════════════════════════════════
; FAT32_INIT - Initialize FAT32 driver
; Reads MBR, finds FAT32 partition, reads boot sector
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
fat32_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Clear mounted flag
    mov byte [fat32_mounted], 0

    ; Read MBR (sector 0)
    xor eax, eax                        ; LBA 0
    mov rdi, fat32_sector_buffer
    call ata_read_sector
    jc .init_error

    ; Check MBR signature
    cmp word [fat32_sector_buffer + 510], 0xAA55
    jne .init_error

    ; Find FAT32 partition in partition table
    ; Partition table starts at offset 446
    mov rbx, fat32_sector_buffer
    add rbx, 446
    mov ecx, 4                          ; 4 partition entries

.check_partition:
    ; Check partition type
    mov al, [rbx + 4]                   ; Partition type
    cmp al, PART_TYPE_FAT32
    je .found_partition
    cmp al, PART_TYPE_FAT32_LBA
    je .found_partition

    add rbx, 16                         ; Next partition entry
    dec ecx
    jnz .check_partition

    ; No FAT32 partition found
    jmp .init_error

.found_partition:
    ; Get partition start LBA (offset 8 in partition entry)
    mov eax, [rbx + 8]
    mov [fat32_partition_lba], eax

    ; Get partition size (offset 12)
    mov eax, [rbx + 12]
    mov [fat32_partition_sectors], eax

    ; Read FAT32 boot sector (BPB)
    mov eax, [fat32_partition_lba]
    mov rdi, fat32_sector_buffer
    call ata_read_sector
    jc .init_error

    ; Parse BPB (BIOS Parameter Block)
    mov rbx, fat32_sector_buffer

    ; Verify FAT32 signature
    cmp byte [rbx + 66], 0x29           ; Extended boot signature
    jne .init_error

    ; Bytes per sector
    movzx eax, word [rbx + 11]
    mov [fat32_bytes_per_sector], eax

    ; Sectors per cluster
    movzx eax, byte [rbx + 13]
    mov [fat32_sectors_per_cluster], eax

    ; Reserved sectors (before FAT)
    movzx eax, word [rbx + 14]
    mov [fat32_reserved_sectors], eax

    ; Number of FATs
    movzx eax, byte [rbx + 16]
    mov [fat32_num_fats], eax

    ; Sectors per FAT (FAT32 specific at offset 36)
    mov eax, [rbx + 36]
    mov [fat32_sectors_per_fat], eax

    ; Root directory cluster
    mov eax, [rbx + 44]
    mov [fat32_root_cluster], eax

    ; Calculate important LBAs
    ; FAT start = partition_lba + reserved_sectors
    mov eax, [fat32_partition_lba]
    add eax, [fat32_reserved_sectors]
    mov [fat32_fat_lba], eax

    ; Data start = fat_lba + (num_fats * sectors_per_fat)
    mov eax, [fat32_num_fats]
    imul eax, [fat32_sectors_per_fat]
    add eax, [fat32_fat_lba]
    mov [fat32_data_lba], eax

    ; Calculate bytes per cluster
    mov eax, [fat32_sectors_per_cluster]
    imul eax, [fat32_bytes_per_sector]
    mov [fat32_bytes_per_cluster], eax

    ; Mark as mounted
    mov byte [fat32_mounted], 1

    clc
    jmp .init_done

.init_error:
    stc

.init_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_READ_CLUSTER - Read a cluster into buffer
; Input: EAX = cluster number, RDI = buffer
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
fat32_read_cluster:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Calculate LBA from cluster
    ; LBA = data_lba + (cluster - 2) * sectors_per_cluster
    sub eax, 2                          ; Clusters start at 2
    mov ebx, [fat32_sectors_per_cluster]
    imul eax, ebx
    add eax, [fat32_data_lba]

    ; Read all sectors in cluster
    mov ecx, [fat32_sectors_per_cluster]
    call ata_read_sectors

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_GET_NEXT_CLUSTER - Get next cluster in chain from FAT
; Input: EAX = current cluster
; Output: EAX = next cluster (or >= 0x0FFFFFF8 if end)
; ════════════════════════════════════════════════════════════════════════════
fat32_get_next_cluster:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Calculate FAT sector and offset
    ; Each FAT entry is 4 bytes
    ; FAT sector = fat_lba + (cluster * 4) / 512
    ; FAT offset = (cluster * 4) % 512

    mov ebx, eax                        ; Save cluster
    shl eax, 2                          ; cluster * 4
    mov ecx, eax
    shr eax, 9                          ; / 512 = sector offset
    and ecx, 511                        ; % 512 = byte offset

    ; Read FAT sector
    add eax, [fat32_fat_lba]
    mov rdi, fat32_fat_buffer
    push rcx
    call ata_read_sector
    pop rcx

    ; Get next cluster value
    mov eax, [fat32_fat_buffer + rcx]
    and eax, 0x0FFFFFFF                 ; Mask to 28 bits

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_READ_DIR - Read directory cluster into buffer
; Input: EAX = directory cluster, RDI = buffer
; Output: ECX = number of entries
; ════════════════════════════════════════════════════════════════════════════
fat32_read_dir:
    push rax
    push rbx
    push rdx
    push rdi

    call fat32_read_cluster

    ; Calculate number of entries
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5                          ; / 32 (dir entry size)

    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_FIND_FILE - Find file in directory
; Input: RSI = filename (8.3 format, space padded), EAX = dir cluster
; Output: RAX = dir entry pointer (or 0 if not found), ECX = file cluster
; ════════════════════════════════════════════════════════════════════════════
fat32_find_file:
    push rbx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov r8, rsi                         ; Save filename
    mov r9d, eax                        ; Save dir cluster

.search_cluster:
    ; Read directory cluster
    mov eax, r9d
    mov rdi, fat32_dir_buffer
    call fat32_read_cluster

    ; Search entries
    mov rbx, fat32_dir_buffer
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5                          ; Number of entries

.check_entry:
    ; Check if entry is empty (first byte 0)
    cmp byte [rbx], 0
    je .not_found                       ; End of directory

    ; Check if deleted entry (0xE5)
    cmp byte [rbx], 0xE5
    je .next_entry

    ; Check if LFN entry
    mov al, [rbx + FAT32_DIR_ATTR]
    cmp al, FAT32_ATTR_LFN
    je .next_entry

    ; Compare filename (11 bytes: 8 name + 3 ext)
    mov rsi, r8
    mov rdi, rbx
    push rcx
    mov ecx, 11
    repe cmpsb
    pop rcx
    je .found

.next_entry:
    add rbx, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jnz .check_entry

    ; Try next cluster in chain
    mov eax, r9d
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .not_found
    mov r9d, eax
    jmp .search_cluster

.found:
    ; Get file cluster
    movzx ecx, word [rbx + FAT32_DIR_CLUSTER_HI]
    shl ecx, 16
    mov cx, [rbx + FAT32_DIR_CLUSTER_LO]
    mov rax, rbx                        ; Return entry pointer
    jmp .find_done

.not_found:
    xor eax, eax
    xor ecx, ecx

.find_done:
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_READ_FILE - Read entire file into buffer
; Input: RSI = filename (8.3 format), RDI = buffer, EDX = max size
; Output: EAX = bytes read (or 0 on error)
; ════════════════════════════════════════════════════════════════════════════
fat32_read_file:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10, rdi                        ; Save buffer
    mov r11d, edx                       ; Save max size

    ; Find file in root directory
    mov eax, [fat32_root_cluster]
    call fat32_find_file
    test rax, rax
    jz .read_error

    ; RAX = dir entry, ECX = first cluster
    ; Get file size
    mov r8d, [rax + FAT32_DIR_SIZE]
    mov r9d, ecx                        ; Starting cluster

    ; Check size limit
    cmp r8d, r11d
    jle .size_ok
    mov r8d, r11d                       ; Truncate to max

.size_ok:
    mov rdi, r10                        ; Buffer
    xor ebx, ebx                        ; Bytes read

.read_loop:
    ; Check if done
    cmp ebx, r8d
    jge .read_done

    ; Read cluster
    mov eax, r9d
    push rdi
    call fat32_read_cluster
    pop rdi

    ; Advance buffer
    add rdi, [fat32_bytes_per_cluster]
    add ebx, [fat32_bytes_per_cluster]

    ; Get next cluster
    mov eax, r9d
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .read_done
    mov r9d, eax
    jmp .read_loop

.read_done:
    ; Return actual file size (not total bytes read)
    mov eax, r8d
    jmp .read_exit

.read_error:
    xor eax, eax

.read_exit:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_LIST_DIR - List directory contents
; Input: EAX = directory cluster, RDI = callback function
;        Callback: RSI = entry pointer, called for each valid entry
; ════════════════════════════════════════════════════════════════════════════
fat32_list_dir:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov r8, rdi                         ; Save callback
    mov r9d, eax                        ; Save dir cluster

.list_cluster:
    ; Read directory cluster
    mov eax, r9d
    mov rdi, fat32_dir_buffer
    call fat32_read_cluster

    ; Process entries
    mov rbx, fat32_dir_buffer
    mov ecx, [fat32_bytes_per_cluster]
    shr ecx, 5

.process_entry:
    ; Check if end of directory
    cmp byte [rbx], 0
    je .list_done

    ; Skip deleted and LFN entries
    cmp byte [rbx], 0xE5
    je .skip_entry
    mov al, [rbx + FAT32_DIR_ATTR]
    cmp al, FAT32_ATTR_LFN
    je .skip_entry

    ; Call callback with entry pointer
    mov rsi, rbx
    push rcx
    push rbx
    call r8
    pop rbx
    pop rcx

.skip_entry:
    add rbx, FAT32_DIR_ENTRY_SIZE
    dec ecx
    jnz .process_entry

    ; Try next cluster
    mov eax, r9d
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .list_done
    mov r9d, eax
    jmp .list_cluster

.list_done:
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_OPEN - Open file and return handle
; Input: RSI = path (e.g., "FILE    TXT")
; Output: RAX = handle (or 0 on error)
; ════════════════════════════════════════════════════════════════════════════
fat32_open:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Find file
    mov eax, [fat32_root_cluster]
    call fat32_find_file
    test rax, rax
    jz .open_fail

    ; Allocate handle slot
    mov rbx, fat32_handles
    mov ecx, FAT32_MAX_HANDLES

.find_slot:
    cmp byte [rbx], 0                   ; Check if slot free
    je .found_slot
    add rbx, FAT32_HANDLE_SIZE
    dec ecx
    jnz .find_slot
    jmp .open_fail                      ; No free slots

.found_slot:
    ; Initialize handle
    mov byte [rbx], 1                   ; Mark as used
    mov [rbx + 4], ecx                  ; First cluster
    mov eax, [rax + FAT32_DIR_SIZE]
    mov [rbx + 8], eax                  ; File size
    mov dword [rbx + 12], 0             ; Current position
    mov [rbx + 16], ecx                 ; Current cluster

    mov rax, rbx                        ; Return handle
    jmp .open_done

.open_fail:
    xor eax, eax

.open_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_CLOSE - Close file handle
; Input: RDI = handle
; ════════════════════════════════════════════════════════════════════════════
fat32_close:
    test rdi, rdi
    jz .close_done
    mov byte [rdi], 0                   ; Mark as free
.close_done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_READ - Read from open file
; Input: RDI = handle, RSI = buffer, EDX = count
; Output: EAX = bytes read
; ════════════════════════════════════════════════════════════════════════════
fat32_read:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10

    ; Validate handle
    test rdi, rdi
    jz .read_zero
    cmp byte [rdi], 0
    je .read_zero

    mov r8, rdi                         ; Handle
    mov r9, rsi                         ; Buffer
    mov r10d, edx                       ; Requested count

    ; Get current position and file size
    mov eax, [r8 + 12]                  ; Position
    mov ebx, [r8 + 8]                   ; Size

    ; Calculate bytes available
    sub ebx, eax                        ; Remaining bytes
    jle .read_zero

    ; Limit to requested count
    cmp ebx, r10d
    jle .count_ok
    mov ebx, r10d

.count_ok:
    ; Read data cluster by cluster
    xor ecx, ecx                        ; Bytes read

.read_chunk:
    cmp ecx, ebx
    jge .read_complete

    ; Calculate position within cluster
    mov eax, [r8 + 12]                  ; Current position
    mov edx, [fat32_bytes_per_cluster]
    xor r10d, r10d
    push rax
    cdq
    div edx                             ; EAX = cluster index, EDX = offset
    pop r10
    mov r10d, edx                       ; Offset in cluster

    ; Read current cluster
    mov eax, [r8 + 16]                  ; Current cluster number
    mov rdi, fat32_cluster_buffer
    push rcx
    push rbx
    call fat32_read_cluster
    pop rbx
    pop rcx

    ; Calculate bytes to copy from this cluster
    mov edx, [fat32_bytes_per_cluster]
    sub edx, r10d                       ; Bytes remaining in cluster
    mov eax, ebx
    sub eax, ecx                        ; Bytes still needed
    cmp edx, eax
    jle .copy_amount_ok
    mov edx, eax

.copy_amount_ok:
    ; Copy data
    push rcx
    lea rsi, [fat32_cluster_buffer + r10]
    mov rdi, r9
    add rdi, rcx
    mov ecx, edx
    rep movsb
    pop rcx

    add ecx, edx                        ; Update bytes read
    add dword [r8 + 12], edx            ; Update position

    ; Check if need next cluster
    mov eax, [r8 + 12]
    mov edx, [fat32_bytes_per_cluster]
    xor r10d, r10d
    div edx
    test edx, edx
    jnz .read_chunk                     ; Still in same cluster

    ; Move to next cluster
    mov eax, [r8 + 16]
    call fat32_get_next_cluster
    cmp eax, FAT32_END_CLUSTER
    jae .read_complete
    mov [r8 + 16], eax
    jmp .read_chunk

.read_complete:
    mov eax, ecx                        ; Return bytes read
    jmp .fread_done

.read_zero:
    xor eax, eax

.fread_done:
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_CONVERT_NAME - Convert filename to 8.3 format
; Input: RSI = source (null-terminated), RDI = dest (11 bytes)
; ════════════════════════════════════════════════════════════════════════════
fat32_convert_name:
    push rax
    push rcx
    push rdi
    push rsi

    ; Fill with spaces
    push rdi
    mov al, ' '
    mov ecx, 11
    rep stosb
    pop rdi

    ; Copy name (up to 8 chars before dot)
    mov ecx, 8

.copy_name:
    lodsb
    test al, al
    jz .name_done
    cmp al, '.'
    je .copy_ext
    ; Convert to uppercase
    cmp al, 'a'
    jb .store_name
    cmp al, 'z'
    ja .store_name
    sub al, 32

.store_name:
    stosb
    dec ecx
    jnz .copy_name

    ; Skip to dot
.skip_to_dot:
    lodsb
    test al, al
    jz .name_done
    cmp al, '.'
    jne .skip_to_dot

.copy_ext:
    ; Position at extension field
    pop rdi                             ; Restore original dest
    push rdi
    add rdi, 8

    mov ecx, 3
.copy_ext_loop:
    lodsb
    test al, al
    jz .name_done
    ; Convert to uppercase
    cmp al, 'a'
    jb .store_ext
    cmp al, 'z'
    ja .store_ext
    sub al, 32

.store_ext:
    stosb
    dec ecx
    jnz .copy_ext_loop

.name_done:
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_GET_ROOT - Get root directory cluster
; Output: EAX = root cluster
; ════════════════════════════════════════════════════════════════════════════
fat32_get_root:
    mov eax, [fat32_root_cluster]
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32_IS_MOUNTED - Check if FAT32 is mounted
; Output: AL = 1 if mounted, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
fat32_is_mounted:
    mov al, [fat32_mounted]
    ret

; ════════════════════════════════════════════════════════════════════════════
; FAT32 DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; Mount state
fat32_mounted:              db 0

; Partition info
fat32_partition_lba:        dd 0
fat32_partition_sectors:    dd 0

; BPB values
fat32_bytes_per_sector:     dd 512
fat32_sectors_per_cluster:  dd 0
fat32_reserved_sectors:     dd 0
fat32_num_fats:             dd 0
fat32_sectors_per_fat:      dd 0
fat32_root_cluster:         dd 0
fat32_bytes_per_cluster:    dd 0

; Calculated values
fat32_fat_lba:              dd 0
fat32_data_lba:             dd 0

; File handles
FAT32_MAX_HANDLES           equ 8
FAT32_HANDLE_SIZE           equ 24
; Handle structure:
;   +0:  in_use (1 byte)
;   +4:  first_cluster (4 bytes)
;   +8:  file_size (4 bytes)
;   +12: position (4 bytes)
;   +16: current_cluster (4 bytes)

fat32_handles:              times FAT32_MAX_HANDLES * FAT32_HANDLE_SIZE db 0

; Buffers
align 512
fat32_sector_buffer:        times 512 db 0
fat32_fat_buffer:           times 512 db 0
fat32_dir_buffer:           times 4096 db 0     ; Up to 8 sectors per cluster
fat32_cluster_buffer:       times 4096 db 0
