; ============================================================================
; DESKTOP_DLG_KEY.ASM - Dialog keyboard handling
; ============================================================================
; Single Responsibility: Handle keys in dialog
; ============================================================================

[BITS 64]

; ============================================================================
; DESKTOP_DLG_ON_KEY - Handle key in dialog
; Input: EDI = scancode
; ============================================================================
desktop_dlg_on_key:
    cmp edi, 0x01               ; ESC
    je desktop_dlg_close
    cmp edi, 0x1C               ; ENTER
    je desktop_dlg_confirm
    cmp edi, 0x0E               ; Backspace
    je .backspace
    cmp edi, 0x48               ; Up arrow
    je .select_up
    cmp edi, 0x50               ; Down arrow
    je .select_down
    jmp .add_char

.select_up:
    mov byte [desktop_dlg_select], 0
    ret

.select_down:
    mov byte [desktop_dlg_select], 1
    ret

.backspace:
    mov eax, [desktop_dlg_cursor]
    test eax, eax
    jz .done
    dec eax
    mov [desktop_dlg_cursor], eax
    lea rdi, [desktop_dlg_input]
    mov byte [rdi + rax], 0
    ret

.add_char:
    mov eax, [desktop_dlg_cursor]
    cmp eax, 30
    jge .done
    ; Convert scancode to ASCII (scancode_to_ascii uses ESI)
    mov esi, edi
    call scancode_to_ascii
    test al, al
    jz .done
    lea rdi, [desktop_dlg_input]
    mov ecx, [desktop_dlg_cursor]
    mov [rdi + rcx], al
    inc dword [desktop_dlg_cursor]

.done:
    ret

