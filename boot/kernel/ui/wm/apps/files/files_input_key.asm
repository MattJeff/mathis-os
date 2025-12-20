; ============================================================================
; FILES_INPUT_KEY.ASM - Keyboard input
; ============================================================================
; Single Responsibility: Handle keyboard navigation
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_ON_KEY - Handle keyboard
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wmf_on_key:
    ; Check if dialog is active first
    push rdi
    call wmf_dialog_key
    pop rdi
    test eax, eax
    jnz .ret_handled

    cmp edi, 0x11               ; W
    je .up
    cmp edi, 0x48               ; Up arrow
    je .up
    cmp edi, 0x1F               ; S
    je .down
    cmp edi, 0x50               ; Down arrow
    je .down
    cmp edi, 0x1C               ; Enter
    je .enter
    cmp edi, 0x0E               ; Backspace
    je .back
    cmp edi, 0x31               ; N
    je .new
    cmp edi, 0x53               ; Delete key
    je .delete
    cmp edi, 0x3C               ; F2
    je .rename
    cmp edi, 0x13               ; R (for rename)
    je .rename
    cmp edi, 0x20               ; D (for delete)
    je .delete

    xor eax, eax
    ret

.up:
    mov eax, [wmf_selected]
    test eax, eax
    jz .handled
    dec eax
    mov [wmf_selected], eax
    jmp .handled

.down:
    mov eax, [wmf_selected]
    inc eax
    cmp eax, [wmf_entry_count]
    jge .handled
    mov [wmf_selected], eax
    jmp .handled

.enter:
    call wmf_open_selected
    jmp .handled

.back:
    call wmf_history_back
    jmp .handled

.new:
    call wmf_create_folder
    jmp .handled

.delete:
    call wmf_dialog_open_delete
    jmp .handled

.rename:
    call wmf_dialog_open_rename
    jmp .handled

.handled:
    mov byte [wm_dirty], 1
.ret_handled:
    mov eax, 1
    ret
