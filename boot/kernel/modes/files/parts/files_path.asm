; ════════════════════════════════════════════════════════════════════════════
; FILES_PATH.ASM - Build full paths for file operations
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FA_BUILD_PATH - Combine vfs_current_path + "/" + filename
; Input:  RDI = filename
; Output: RAX = pointer to fa_full_path buffer
; ════════════════════════════════════════════════════════════════════════════
fa_build_path:
    push rsi
    push rcx
    push rdi

    ; Clear buffer
    lea rdi, [fa_full_path]
    xor al, al
    mov ecx, 128
    rep stosb

    ; Copy current path
    lea rdi, [fa_full_path]
    lea rsi, [vfs_current_path]
.copy_path:
    lodsb
    test al, al
    jz .path_done
    stosb
    jmp .copy_path

.path_done:
    ; Check if we need slash (path not empty and doesn't end with /)
    lea rax, [fa_full_path]
    cmp rdi, rax
    je .add_slash              ; Empty path, add /
    cmp byte [rdi-1], '/'
    je .copy_name              ; Already ends with /

.add_slash:
    mov byte [rdi], '/'
    inc rdi

.copy_name:
    ; Copy filename
    pop rsi                    ; Original RDI (filename) now in RSI
    push rsi
.copy_name_loop:
    lodsb
    stosb
    test al, al
    jnz .copy_name_loop

    ; Return buffer pointer
    lea rax, [fa_full_path]

    pop rdi
    pop rcx
    pop rsi
    ret

; Buffers for full paths
fa_full_path:  times 128 db 0
fa_full_path2: times 128 db 0

; ════════════════════════════════════════════════════════════════════════════
; FA_BUILD_PATH2 - Same as fa_build_path but uses second buffer
; Input:  RDI = filename
; Output: RAX = pointer to fa_full_path2 buffer
; ════════════════════════════════════════════════════════════════════════════
fa_build_path2:
    push rsi
    push rcx
    push rdi

    ; Clear buffer
    lea rdi, [fa_full_path2]
    xor al, al
    mov ecx, 128
    rep stosb

    ; Copy current path
    lea rdi, [fa_full_path2]
    lea rsi, [vfs_current_path]
.copy_path:
    lodsb
    test al, al
    jz .path_done
    stosb
    jmp .copy_path

.path_done:
    lea rax, [fa_full_path2]
    cmp rdi, rax
    je .add_slash
    cmp byte [rdi-1], '/'
    je .copy_name

.add_slash:
    mov byte [rdi], '/'
    inc rdi

.copy_name:
    pop rsi
    push rsi
.copy_name_loop:
    lodsb
    stosb
    test al, al
    jnz .copy_name_loop

    lea rax, [fa_full_path2]

    pop rdi
    pop rcx
    pop rsi
    ret
