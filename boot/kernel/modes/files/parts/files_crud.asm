; ════════════════════════════════════════════════════════════════════════════
; FILES_CRUD.ASM - Save/Refresh operations for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FA_SAVE_FILE - Save current editor content to disk
; ════════════════════════════════════════════════════════════════════════════
fa_save_file:
    push rbx
    push r12
    push r13

    ; Check if editor exists
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .save_done

    ; Check if we have a filename
    mov r12, [fa_current_file]
    test r12, r12
    jz .save_done

    ; Get text from editor
    mov rdi, [fa_editor]
    call text_editor_get_text       ; RAX = text ptr, EDX = length
    test rax, rax
    jz .save_done

    mov r13, rax                    ; r13 = text content
    mov ebx, edx                    ; ebx = length

    ; Write file using CRUD
    mov rdi, r12                    ; path = filename
    mov rsi, r13                    ; data = text content
    mov edx, ebx                    ; size = length
    call crud_write_file
    cmp eax, -1
    je .save_failed

    ; Success - clear modified flag
    mov rdi, [fa_editor]
    mov dword [rdi + TE_MODIFIED], 0
    or dword [rdi + W_FLAGS], WF_DIRTY
    jmp .save_refresh

.save_failed:
    ; Write failed - keep modified flag set

.save_refresh:
    mov byte [files_dirty], 1

.save_done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_REFRESH_LIST - Reload file list from filesystem
; ════════════════════════════════════════════════════════════════════════════
fa_refresh_list:
    mov byte [files_dirty], 1
    ret
