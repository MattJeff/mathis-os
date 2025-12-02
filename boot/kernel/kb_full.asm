; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - FULL KEYBOARD HANDLER
; Called from keyboard_isr stub - NO SIZE LIMIT!
; EBX contains scancode
; ════════════════════════════════════════════════════════════════════════════

kb_process:
    ; === SHIFT KEY HANDLING ===
    cmp bl, 42              ; Left Shift press
    je .shift_on
    cmp bl, 54              ; Right Shift press
    je .shift_on
    cmp bl, 170             ; Left Shift release (42+128)
    je .shift_off
    cmp bl, 182             ; Right Shift release (54+128)
    je .shift_off
    
    ; Ignore other key releases
    test bl, 0x80
    jnz .done
    
    ; Check edit mode
    cmp byte [edit_mode], 1
    je .edit_key
    
    ; === NORMAL MODE ===
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Use shift table if shift pressed
    cmp byte [kb_shift], 1
    je .use_shift
    mov al, [scancode_table + eax]
    jmp .got_char
.use_shift:
    mov al, [kb_shift_table + eax]
.got_char:
    test al, al
    jz .done
    
    ; Enter key
    cmp al, 0x0D
    je .do_enter
    
    ; Backspace
    cmp al, 0x08
    je .do_backspace
    
    ; Normal char - add to buffer
    mov edx, [cmd_length]
    cmp edx, 60
    jge .done
    mov [cmd_buffer + edx], al
    inc dword [cmd_length]
    
    ; Display char
    mov ah, 0x0F
    mov edi, [cursor_offset]
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    pop ebx
    inc dword [cursor_offset]
    ret

.do_enter:
    cmp dword [cmd_length], 0
    je .done
    call shell_command
    ret

.do_backspace:
    cmp dword [cmd_length], 0
    je .done
    dec dword [cmd_length]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    pop ebx
    ret

.edit_key:
    ; ESC = save (scancode 1)
    cmp bl, 1
    je .edit_save
    
    ; Backspace in edit mode (scancode 14)
    cmp bl, 14
    je .edit_backspace
    
    ; Convert scancode with shift support
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    cmp byte [kb_shift], 1
    je .edit_shift
    mov al, [scancode_table + eax]
    jmp .edit_got
.edit_shift:
    mov al, [kb_shift_table + eax]
.edit_got:
    test al, al
    jz .done
    
    ; Add to file content
    mov edx, [file_content_len]
    cmp edx, 500
    jge .done
    mov [file_content + edx], al
    inc dword [file_content_len]
    
    ; Display in yellow
    mov ah, 0x0E
    mov edi, [cursor_offset]
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    pop ebx
    inc dword [cursor_offset]
    ret

.edit_backspace:
    cmp dword [file_content_len], 0
    je .done
    dec dword [file_content_len]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    pop ebx
    ret

.edit_save:
    mov edx, [file_content_len]
    mov byte [file_content + edx], 0
    mov byte [edit_mode], 0
    inc dword [prompt_line]
    
    push esi
    mov esi, msg_file_saved
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
.save_msg:
    lodsb
    test al, al
    jz .save_done
    stosw
    jmp .save_msg
.save_done:
    pop ebx
    pop esi
    call shell_prompt
    ret

.shift_on:
    mov byte [kb_shift], 1
    ret

.shift_off:
    mov byte [kb_shift], 0
    ret

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD DATA
; ════════════════════════════════════════════════════════════════════════════
kb_shift: db 0

kb_shift_table:
    db 0, 27, '!@#$%^&*()_+', 8, 9     ; Shift + numbers = symbols
    db 'QWERTYUIOP{}', 13, 0            ; Uppercase letters
    db 'ASDFGHJKL:"~', 0, '|'           
    db 'ZXCVBNM<>?', 0, '*', 0, ' '
    times 70 db 0
