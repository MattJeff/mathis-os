; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - I/O MODULE
; Input/Output - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

vm_op_print_int:
    mov eax, [ebp]
    mov [vm_print_value], eax
    jmp vm_loop

vm_op_print_string:
    push esi
    push edi
    
    mov esi, [ebp]
    add esi, 4
    add ebp, 4
    
    call vga_newline
    
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0F

vm_print_str_loop:
    lodsb
    test al, al
    jz vm_print_str_done
    stosw
    jmp vm_print_str_loop
    
vm_print_str_done:
    pop edi
    pop esi
    jmp vm_loop

vm_op_print_char:
    push edi
    
    mov eax, [ebp]
    add ebp, 4
    
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov ecx, [cursor_offset]
    shl ecx, 1
    add ebx, ecx
    mov edi, ebx
    
    mov ah, 0x0F
    stosw
    inc dword [cursor_offset]
    
    pop edi
    jmp vm_loop

vm_op_print_nl:
    inc dword [prompt_line]
    mov dword [cursor_offset], 0
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; INPUT OPERATIONS
; ════════════════════════════════════════════════════════════════════════════

vm_op_read_char:
    ; READ_CHAR: Read character from keyboard (blocking)
    ; For now, just push 0 (would need keyboard buffer)
    sub ebp, 4
    mov dword [ebp], 0
    jmp vm_loop

vm_op_read_int:
    ; READ_INT: Read integer (blocking)
    ; For now, just push 0
    sub ebp, 4
    mov dword [ebp], 0
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; FORMATTED OUTPUT
; ════════════════════════════════════════════════════════════════════════════

vm_op_print_hex:
    ; PRINT_HEX: Print number in hexadecimal
    push edi
    mov eax, [ebp]
    add ebp, 4

    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov ecx, [cursor_offset]
    shl ecx, 1
    add ebx, ecx
    mov edi, ebx

    ; Print "0x"
    mov word [edi], 0x0F30          ; '0'
    add edi, 2
    mov word [edi], 0x0F78          ; 'x'
    add edi, 2
    add dword [cursor_offset], 2

    ; Print 8 hex digits
    mov ecx, 8
.hex_loop:
    rol eax, 4
    mov ebx, eax
    and ebx, 0x0F
    cmp ebx, 10
    jl .hex_digit
    add ebx, 7                      ; 'A'-'0'-10
.hex_digit:
    add ebx, '0'
    mov bh, 0x0F
    mov [edi], bx
    add edi, 2
    inc dword [cursor_offset]
    loop .hex_loop

    pop edi
    jmp vm_loop

vm_op_print_bin:
    ; PRINT_BIN: Print number in binary
    push edi
    mov eax, [ebp]
    add ebp, 4

    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov ecx, [cursor_offset]
    shl ecx, 1
    add ebx, ecx
    mov edi, ebx

    ; Print "0b"
    mov word [edi], 0x0F30          ; '0'
    add edi, 2
    mov word [edi], 0x0F62          ; 'b'
    add edi, 2
    add dword [cursor_offset], 2

    ; Print 32 binary digits
    mov ecx, 32
.bin_loop:
    rol eax, 1
    mov ebx, eax
    and ebx, 1
    add ebx, '0'
    mov bh, 0x0F
    mov [edi], bx
    add edi, 2
    inc dword [cursor_offset]
    loop .bin_loop

    pop edi
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
vm_print_value: dd 0
