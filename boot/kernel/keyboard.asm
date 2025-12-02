; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - KEYBOARD MODULE (FINAL FIX)
; Local data to prevent segmentation faults
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    pushad              ; Save all registers
    
    in al, 0x60         ; Read scancode
    mov bl, al          ; Save scancode
    
    mov al, 0x20        ; EOI
    out 0x20, al        ; Send EOI
    
    call process_key    ; Process the key
    
    popad               ; Restore registers
    iret

; ════════════════════════════════════════════════════════════════════════════
; KEY PROCESSING
; ════════════════════════════════════════════════════════════════════════════
process_key:
    pushad
    
    ; Check for key release (bit 7)
    test bl, 0x80
    jnz .check_release
    
    ; === PRESS HANDLING ===
    
    ; Shift Key Press
    cmp bl, 42          ; Left Shift
    je .shift_on
    cmp bl, 54          ; Right Shift
    je .shift_on
    
    ; Check edit mode
    cmp byte [edit_mode], 1
    je .edit_mode_handler
    
    ; Normal Mode
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Check Shift State
    cmp byte [shift_state], 1
    je .use_shift
    mov al, [scancode_table + eax]
    jmp .got_char
.use_shift:
    mov al, [shift_table + eax]
.got_char:
    
    test al, al
    jz .done
    
    ; Handle Special Keys
    cmp al, 0x0D        ; Enter
    je .handle_enter
    cmp al, 0x08        ; Backspace
    je .handle_backspace
    
    ; Add to buffer
    mov edx, [cmd_length]
    cmp edx, 60
    jge .done
    mov [cmd_buffer + edx], al
    inc dword [cmd_length]
    
    ; Display Character
    call print_char_at_cursor
    jmp .done

.check_release:
    ; Shift Key Release
    and bl, 0x7F        ; Clear bit 7
    cmp bl, 42
    je .shift_off
    cmp bl, 54
    je .shift_off
    jmp .done

.shift_on:
    mov byte [shift_state], 1
    jmp .done

.shift_off:
    mov byte [shift_state], 0
    jmp .done

; ════════════════════════════════════════════════════════════════════════════
; COMMAND HANDLERS
; ════════════════════════════════════════════════════════════════════════════

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
    
    ; Clear character on screen
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720  ; Space
    jmp .done

; ════════════════════════════════════════════════════════════════════════════
; EDIT MODE HANDLER - TEST 4: Full (display + file write)
; ════════════════════════════════════════════════════════════════════════════
.edit_mode_handler:
    ; ESC = save (scancode 1)
    cmp bl, 1
    je .edit_save
    
    ; Backspace in edit mode (scancode 14)
    cmp bl, 14
    je .edit_backspace
    
    ; Normal char
    movzx eax, bl
    cmp eax, 58
    jge .done
    
    ; Check Shift
    cmp byte [shift_state], 1
    je .edit_shift
    mov al, [scancode_table + eax]
    jmp .edit_got
.edit_shift:
    mov al, [shift_table + eax]
.edit_got:
    test al, al
    jz .done
    
    ; TEST 4: BOTH - Write to file AND display
    mov edx, [file_content_len]
    cmp edx, 500
    jge .done
    mov [file_content + edx], al
    inc dword [file_content_len]
    
    ; Display in Yellow (0x0E)
    mov ah, 0x0E
    call print_char_at_cursor
    jmp .done

.edit_backspace:
    cmp dword [file_content_len], 0
    je .done
    dec dword [file_content_len]
    dec dword [cursor_offset]
    
    ; Clear char
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov word [edi], 0x0720
    jmp .done

.edit_save:
    mov edx, [file_content_len]
    mov byte [file_content + edx], 0 ; Null terminate
    mov byte [edit_mode], 0
    
    ; New line and prompt
    call vga_newline
    call shell_prompt
    jmp .done

.done:
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; HELPER FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════
print_char_at_cursor:
    mov ah, 0x0F
    mov edi, [cursor_offset]
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    lea edi, [ebx + edi*2]
    mov [edi], ax
    inc dword [cursor_offset]
    ret

; ════════════════════════════════════════════════════════════════════════════
; LOCAL DATA - MOVED FROM DATA.ASM
; ════════════════════════════════════════════════════════════════════════════

; Variables
cursor_offset:      dd 4    ; Start after prompt "> "
cmd_length:         dd 0
cmd_buffer:         times 64 db 0
prompt_line:        dd 9    ; Start line
edit_mode:          db 0
file_content_len:   dd 0
file_content:       times 512 db 0
shift_state:        db 0

; Tables
scancode_table:
    db 0, 27, '1234567890-=', 8, 9
    db 'qwertyuiop[]', 13, 0
    db 'asdfghjkl', 0x3B, 0x27, '`', 0, '\'
    db 'zxcvbnm,./', 0, '*', 0, ' '
    times 70 db 0

shift_table:
    db 0, 27, '!@#$%^&*()_+', 8, 9
    db 'QWERTYUIOP{}', 13, 0
    db 'ASDFGHJKL:"~', 0, '|'
    db 'ZXCVBNM<>?', 0, '*', 0, ' '
    times 70 db 0
