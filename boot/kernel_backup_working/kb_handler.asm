; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD HANDLER - Full processing with SHIFT support
; Called from kb_stub with scancode in EBX
; This can grow as large as needed!
; ════════════════════════════════════════════════════════════════════════════

kb_handler:
    ; === SHIFT KEY DETECTION ===
    cmp bl, 42                  ; Left Shift press
    je .shift_press
    cmp bl, 54                  ; Right Shift press  
    je .shift_press
    cmp bl, 170                 ; Left Shift release
    je .shift_release
    cmp bl, 182                 ; Right Shift release
    je .shift_release
    
    ; Ignore other key releases
    test bl, 0x80
    jnz .done
    
    ; === NEURAL ACTIVATION ===
    ; (Future: Send signal to keyboard neuron)
    ; push esi
    ; push eax
    ; mov esi, neural_kernel.keyboard_neuron
    ; mov al, 20                  ; Signal strength
    ; mov [last_scancode], bl
    ; call propagate_signal
    ; pop eax
    ; pop esi
    
    ; === MODE CHECK ===
    cmp byte [edit_mode], 1
    je .edit_mode
    
    ; === NORMAL MODE PROCESSING ===
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Use shifted table if shift pressed
    cmp byte [shift_pressed], 1
    je .use_shifted
    mov al, [scancode_table + eax]
    jmp .got_char
.use_shifted:
    mov al, [scancode_shift + eax]
.got_char:
    test al, al
    jz .done
    
    ; Special keys
    cmp al, 0x0D                ; Enter
    je .enter_key
    cmp al, 0x08                ; Backspace
    je .backspace_key
    
    ; Normal character
    mov edx, [cmd_length]
    cmp edx, 60
    jge .done
    mov [cmd_buffer + edx], al
    inc dword [cmd_length]
    
    ; Display character
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

.enter_key:
    cmp dword [cmd_length], 0
    je .done
    call shell_command
    ret

.backspace_key:
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

; === EDIT MODE ===
.edit_mode:
    cmp bl, 1                   ; ESC to save
    je .save_file
    
    cmp bl, 14                  ; Backspace
    je .edit_backspace
    
    ; Convert scancode with shift support
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    cmp byte [shift_pressed], 1
    je .edit_shifted
    mov al, [scancode_table + eax]
    jmp .edit_got_char
.edit_shifted:
    mov al, [scancode_shift + eax]
.edit_got_char:
    test al, al
    jz .done
    
    ; Add to file
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

.save_file:
    mov edx, [file_content_len]
    mov byte [file_content + edx], 0
    mov byte [edit_mode], 0
    inc dword [prompt_line]
    
    mov esi, msg_file_saved
    push ebx
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
.save_loop:
    lodsb
    test al, al
    jz .save_done
    stosw
    jmp .save_loop
.save_done:
    pop ebx
    call shell_prompt
    ret

; === SHIFT HANDLERS ===
.shift_press:
    mov byte [shift_pressed], 1
    ; Neural feedback - shift awareness (future)
    ; mov esi, neural_kernel.pattern_neuron
    ; mov al, 30
    ; call propagate_signal
    ret

.shift_release:
    mov byte [shift_pressed], 0
    ret

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; SHIFT DATA (now in variable zone!)
; ════════════════════════════════════════════════════════════════════════════
shift_pressed: db 0

scancode_shift:
    db 0, 27, '!@#$%^&*()_+', 8, 9     ; Shift + numbers = symbols
    db 'QWERTYUIOP{}', 13, 0            ; Uppercase letters
    db 'ASDFGHJKL:"~', 0, '|'           
    db 'ZXCVBNM<>?', 0, '*', 0, ' '
    times 70 db 0

; display_thought will be added with neural core later
