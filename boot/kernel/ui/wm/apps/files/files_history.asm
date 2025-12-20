; ============================================================================
; FILES_HISTORY.ASM - Navigation history (back/forward)
; ============================================================================

[BITS 64]

; WMF_HISTORY_PUSH - Push location to history. Input: EDI = location
wmf_history_push:
    push rbx
    push rcx
    mov eax, [wmf_history_pos]
    mov [wmf_history_len], eax
    cmp eax, WMF_HISTORY_MAX
    jge .shift
    lea rbx, [wmf_history]
    mov [rbx + rax*4], edi
    inc eax
    mov [wmf_history_pos], eax
    mov [wmf_history_len], eax
    jmp .done
.shift:
    lea rbx, [wmf_history]
    mov ecx, WMF_HISTORY_MAX - 1
.shift_loop:
    mov eax, [rbx + 4]
    mov [rbx], eax
    add rbx, 4
    dec ecx
    jnz .shift_loop
    mov [rbx], edi
.done:
    pop rcx
    pop rbx
    ret

; WMF_HISTORY_BACK - Go back. Output: EAX = 1 if navigated
wmf_history_back:
    push rbx
    mov eax, [wmf_history_pos]
    cmp eax, 2
    jl .no_back
    dec eax
    mov [wmf_history_pos], eax
    lea rbx, [wmf_history]
    dec eax
    mov edi, [rbx + rax*4]
    call wmf_history_navigate
    mov eax, 1
    pop rbx
    ret
.no_back:
    xor eax, eax
    pop rbx
    ret

; WMF_HISTORY_FWD - Go forward. Output: EAX = 1 if navigated
wmf_history_fwd:
    push rbx
    mov eax, [wmf_history_pos]
    cmp eax, [wmf_history_len]
    jge .no_fwd
    lea rbx, [wmf_history]
    mov edi, [rbx + rax*4]
    inc dword [wmf_history_pos]
    call wmf_history_navigate
    mov eax, 1
    pop rbx
    ret
.no_fwd:
    xor eax, eax
    pop rbx
    ret

; Internal: navigate and reset state
wmf_history_navigate:
    call vfs_goto_loc
    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0
    mov byte [wm_dirty], 1
    ret
