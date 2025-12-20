; ============================================================================
; FILES_DIALOG_KEY.ASM - Dialog keyboard handling
; ============================================================================
; Single Responsibility: Handle keyboard input in dialog
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_DIALOG_KEY - Handle key in dialog
; Input: EDI = scancode
; Output: EAX = 1 if handled, 0 if not
; ============================================================================
wmf_dialog_key:
    cmp dword [wmf_dialog_mode], WMF_DLG_NONE
    je .not_handled

    cmp edi, 0x01               ; ESC
    je .cancel
    cmp edi, 0x1C               ; Enter
    je .confirm
    cmp edi, 0x0E               ; Backspace
    je .backspace

    ; Try to add character
    call wmf_scancode_to_char
    test al, al
    jz .handled

    ; Add char if room
    mov ecx, [wmf_dialog_cursor]
    cmp ecx, 30
    jge .handled
    lea rdi, [wmf_dialog_input]
    mov [rdi + rcx], al
    inc dword [wmf_dialog_cursor]
    mov byte [wm_dirty], 1
    jmp .handled

.backspace:
    mov ecx, [wmf_dialog_cursor]
    test ecx, ecx
    jz .handled
    dec ecx
    mov [wmf_dialog_cursor], ecx
    lea rdi, [wmf_dialog_input]
    mov byte [rdi + rcx], 0
    mov byte [wm_dirty], 1
    jmp .handled

.cancel:
    call wmf_dialog_close
    jmp .handled

.confirm:
    call wmf_dialog_confirm
    jmp .handled

.handled:
    mov eax, 1
    ret
.not_handled:
    xor eax, eax
    ret

; ============================================================================
; WMF_SCANCODE_TO_CHAR - Convert scancode to ASCII
; Input: EDI = scancode
; Output: AL = ASCII char (0 if none)
; ============================================================================
wmf_scancode_to_char:
    cmp edi, 0x39
    ja .none
    lea rax, [.table]
    movzx eax, byte [rax + rdi]
    ret
.none:
    xor eax, eax
    ret
.table:
    db 0,0,'1234567890-=',0,0,'QWERTYUIOP[]',0,0
    db 'ASDFGHJKL',0,0,0,0,0,'ZXCVBNM',0,0,0,0,0,' '
