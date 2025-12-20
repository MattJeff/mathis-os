; ============================================================================
; PATH_SPLIT.ASM - Split path into parent directory and filename
; ============================================================================

[BITS 64]

; ============================================================================
; PATH_SPLIT - Split "/dir/subdir/file" into parent "/dir/subdir" and name "file"
; Input:  RDI = full path
; Output: RAX = parent path (path_parent_buf), RDX = filename pointer
; ============================================================================
path_split:
    push rbx
    push rcx
    push rsi

    mov rsi, rdi                    ; rsi = source path

    ; Find last '/' in path
    xor ecx, ecx                    ; ecx = last slash position
    xor ebx, ebx                    ; ebx = current position

.find_slash:
    mov al, [rsi + rbx]
    test al, al
    jz .split_done
    cmp al, '/'
    jne .next_char
    mov ecx, ebx                    ; Remember this slash position
.next_char:
    inc ebx
    jmp .find_slash

.split_done:
    ; ecx = position of last slash (0 if none)
    ; ebx = string length

    ; Copy parent path (up to last slash)
    lea rdi, [path_parent_buf]
    test ecx, ecx
    jz .root_parent                 ; No slash = parent is root

    ; Copy characters up to (not including) last slash
    xor eax, eax
.copy_parent:
    cmp eax, ecx
    jge .end_parent
    mov bl, [rsi + rax]
    mov [rdi + rax], bl
    inc eax
    jmp .copy_parent

.end_parent:
    mov byte [rdi + rax], 0
    jmp .set_filename

.root_parent:
    ; Parent is "/" (root)
    mov byte [rdi], '/'
    mov byte [rdi + 1], 0

.set_filename:
    ; Filename starts after last slash
    lea rdx, [rsi + rcx]
    cmp byte [rdx], '/'
    jne .done
    inc rdx                         ; Skip the slash

.done:
    lea rax, [path_parent_buf]

    pop rsi
    pop rcx
    pop rbx
    ret

; Buffer for parent path
path_parent_buf: times 128 db 0
