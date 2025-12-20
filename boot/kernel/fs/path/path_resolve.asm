; ============================================================================
; PATH_RESOLVE.ASM - Resolve path to FAT32 cluster
; ============================================================================

[BITS 64]

; ============================================================================
; PATH_RESOLVE - Resolve path to directory cluster
; Input:  RDI = path string (e.g., "/desktop" or "/")
; Output: EAX = cluster number, or -1 on error
; ============================================================================
path_resolve:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13

    ; Parse path into segments
    call path_parse                 ; EAX = segment count
    mov r12d, eax                   ; r12 = segment count

    ; Start from root cluster
    mov r13d, [fat32_root_cluster]  ; r13 = current cluster

    ; If no segments, return root
    test r12d, r12d
    jz .done

    ; Traverse each segment
    xor ecx, ecx                    ; ecx = segment index

.traverse_loop:
    cmp ecx, r12d
    jge .done

    ; Get segment name pointer
    push rcx
    mov eax, ecx
    imul eax, PATH_SEG_SIZE
    lea rsi, [path_segments + rax]  ; rsi = segment name (8.3 format)

    ; Find in current directory
    mov eax, r13d                   ; eax = current dir cluster
    call fat32_find_file            ; rax = entry, ecx = file cluster

    pop rcx                         ; Restore loop counter
    test rax, rax
    jz .not_found

    ; Check if it's a directory
    mov al, [rax + FAT32_DIR_ATTR]
    test al, FAT32_ATTR_DIRECTORY
    jz .not_found                   ; Not a directory, can't traverse

    ; Move to subdirectory cluster
    mov r13d, ecx                   ; ecx contains cluster from fat32_find_file

    inc ecx
    jmp .traverse_loop

.done:
    mov eax, r13d
    jmp .exit

.not_found:
    mov eax, -1

.exit:
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
