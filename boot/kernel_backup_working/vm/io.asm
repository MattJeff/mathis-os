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

vm_print_value: dd 0
