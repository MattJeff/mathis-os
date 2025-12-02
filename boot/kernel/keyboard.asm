; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - KEYBOARD MODULE
; Must be at exactly 0x10200 (called from IDT)
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    pushad
    push eax
    
    ; Read scancode
    in al, 0x60
    
    ; Ignore key release
    test al, 0x80
    jnz .done
    
    ; Check edit mode
    cmp byte [edit_mode], 1
    je .edit_mode_key
    
    ; Convert scancode to ASCII
    movzx ebx, al
    add ebx, scancode_table
    mov al, [ebx]
    
    test al, al
    jz .done
    
    ; Enter
    cmp al, 0x0D
    je .handle_enter
    
    ; Backspace
    cmp al, 0x08
    je .handle_backspace
    
    ; Normal char
    mov cl, al
    mov edx, [cmd_length]
    cmp edx, 60
    jge .done
    mov [cmd_buffer + edx], cl
    inc dword [cmd_length]
    
    ; Display
    mov ah, 0x0F
    mov al, cl
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi
    add edi, ebx
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .done

.handle_enter:
    cmp dword [cmd_length], 0
    je .done
    call shell_command
    jmp .done

.handle_backspace:
    cmp dword [cmd_length], 0
    je .done
    dec dword [cmd_length]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi
    add edi, ebx
    mov word [edi], 0x0720
    jmp .done

.edit_mode_key:
    ; ESC (scancode 1)
    cmp al, 1
    je .edit_save
    
    ; Backspace in edit mode (scancode 14)
    cmp al, 14
    je .edit_backspace
    
    movzx ebx, al
    add ebx, scancode_table
    mov al, [ebx]
    test al, al
    jz .done
    
    ; Enter in edit mode
    cmp al, 0x0D
    je .edit_newline
    
    ; Add to file content
    mov edx, [file_content_len]
    cmp edx, 500
    jge .done
    mov [file_content + edx], al
    inc dword [file_content_len]
    
    ; Display yellow
    mov ah, 0x0E
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi
    add edi, ebx
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .done

.edit_backspace:
    cmp dword [file_content_len], 0
    je .done
    dec dword [file_content_len]
    cmp dword [cursor_offset], 0
    je .done
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add edi, edi
    add edi, ebx
    mov word [edi], 0x0720
    jmp .done

.edit_newline:
    mov edx, [file_content_len]
    mov byte [file_content + edx], ';'
    inc dword [file_content_len]
    inc dword [prompt_line]
    mov dword [cursor_offset], 0
    jmp .done

.edit_save:
    ; Null-terminate the file content
    mov edx, [file_content_len]
    mov byte [file_content + edx], 0
    
    mov byte [edit_mode], 0
    inc dword [prompt_line]
    mov esi, msg_file_saved
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
    call print_string
    call shell_prompt
    jmp .done

.done:
    mov al, 0x20
    out 0x20, al
    pop eax
    popad
    iret
