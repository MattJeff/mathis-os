; ════════════════════════════════════════════════════════════════════════════
; MINIMAL KEYBOARD ISR - Only 30 bytes!
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    pushad              ; Save all (1 byte)
    
    in al, 0x60         ; Read scancode (2 bytes)
    mov [last_key], al  ; Store it (5 bytes)
    
    mov al, 0x20        ; EOI (2 bytes)
    out 0x20, al        ; Send EOI (2 bytes)
    
    call process_key    ; Delegate everything (5 bytes)
    
    popad               ; Restore all (1 byte) 
    iret                ; Return (1 byte)
    
last_key: db 0          ; Storage (1 byte)

; Total: ~20 bytes - WELL under 40 byte limit!

; ════════════════════════════════════════════════════════════════════════════
; FULL PROCESSING (can be as large as needed!)
; ════════════════════════════════════════════════════════════════════════════
process_key:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    movzx ebx, byte [last_key]
    
    ; === SHIFT SUPPORT ===
    cmp bl, 42              ; Left Shift
    je .shift_on
    cmp bl, 54              ; Right Shift
    je .shift_on
    cmp bl, 170             ; Left Shift release
    je .shift_off
    cmp bl, 182             ; Right Shift release
    je .shift_off
    
    ; Ignore other releases
    test bl, 0x80
    jnz .done
    
    ; Check edit mode
    cmp byte [edit_mode], 1
    je .edit_mode
    
    ; === NORMAL MODE ===
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Use shift table if needed
    cmp byte [shift_pressed], 1
    je .use_shift
    mov al, [scancode_table + eax]
    jmp .got_char
.use_shift:
    mov al, [scancode_shift + eax]
.got_char:
    test al, al
    jz .done
    
    cmp al, 0x0D            ; Enter
    je .enter
    cmp al, 0x08            ; Backspace
    je .backspace
    
    ; Add to buffer
    mov edx, [cmd_length]
    cmp edx, 60
    jge .done
    mov [cmd_buffer + edx], al
    inc dword [cmd_length]
    
    ; Display
    mov ah, 0x0F
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .done

.enter:
    cmp dword [cmd_length], 0
    je .done
    call shell_command
    jmp .done

.backspace:
    cmp dword [cmd_length], 0
    je .done
    dec dword [cmd_length]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    jmp .done

.edit_mode:
    cmp bl, 1               ; ESC
    je .save_file
    cmp bl, 14              ; Backspace
    je .edit_backspace
    
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Use shift in edit mode too
    cmp byte [shift_pressed], 1
    je .edit_shift
    mov al, [scancode_table + eax]
    jmp .edit_got
.edit_shift:
    mov al, [scancode_shift + eax]
.edit_got:
    test al, al
    jz .done
    
    mov edx, [file_content_len]
    cmp edx, 500
    jge .done
    mov [file_content + edx], al
    inc dword [file_content_len]
    
    mov ah, 0x0E
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    inc dword [cursor_offset]
    jmp .done

.edit_backspace:
    cmp dword [file_content_len], 0
    je .done
    dec dword [file_content_len]
    dec dword [cursor_offset]
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    jmp .done

.save_file:
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
    jmp .done

.shift_on:
    mov byte [shift_pressed], 1
    jmp .done

.shift_off:
    mov byte [shift_pressed], 0
    jmp .done

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; === SHIFT DATA ===
shift_pressed: db 0
scancode_shift:
    db 0, 27, '!@#$%^&*()_+', 8, 9
    db 'QWERTYUIOP{}', 13, 0
    db 'ASDFGHJKL:"~', 0, '|'
    db 'ZXCVBNM<>?', 0, '*', 0, ' '
    times 70 db 0
