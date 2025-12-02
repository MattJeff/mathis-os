; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - KEYBOARD MODULE
; Must be at exactly 0x10200 (called from IDT)
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Read scancode FIRST
    in al, 0x60
    mov bl, al
    
    ; Send EOI
    mov al, 0x20
    out 0x20, al
    
    ; Ignore key release
    test bl, 0x80
    jnz .isr_done
    
    ; Check edit mode
    cmp byte [edit_mode], 1
    je .edit_key
    
    ; Convert scancode
    movzx eax, bl
    cmp eax, 58
    jge .isr_done
    mov al, [scancode_table + eax]
    test al, al
    jz .isr_done
    
    ; Enter key
    cmp al, 0x0D
    je .do_enter
    
    ; Backspace
    cmp al, 0x08
    je .do_backspace
    
    ; Normal char - add to buffer
    mov edx, [cmd_length]
    cmp edx, 60
    jge .isr_done
    mov [cmd_buffer + edx], al
    inc dword [cmd_length]
    
    ; Display char
    mov ah, 0x0F
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .isr_done

.do_enter:
    cmp dword [cmd_length], 0
    je .isr_done
    call shell_command
    jmp .isr_done

.do_backspace:
    cmp dword [cmd_length], 0
    je .isr_done
    dec dword [cmd_length]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    jmp .isr_done

.edit_key:
    ; ESC = save (scancode 1)
    cmp bl, 1
    je .edit_save
    
    ; Backspace in edit mode (scancode 14)
    cmp bl, 14
    je .edit_backspace
    
    ; Convert scancode
    movzx eax, bl
    cmp eax, 58
    jge .isr_done
    mov al, [scancode_table + eax]
    test al, al
    jz .isr_done
    
    ; Add to file content
    mov edx, [file_content_len]
    cmp edx, 500
    jge .isr_done
    mov [file_content + edx], al
    inc dword [file_content_len]
    
    ; Display in yellow
    mov ah, 0x0E
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .isr_done

.edit_backspace:
    cmp dword [file_content_len], 0
    je .isr_done
    dec dword [file_content_len]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    jmp .isr_done

.edit_save:
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
.save_msg:
    lodsb
    test al, al
    jz .save_done
    stosw
    jmp .save_msg
.save_done:
    call shell_prompt

.isr_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    iret
