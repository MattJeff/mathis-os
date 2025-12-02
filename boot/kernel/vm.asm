; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - VM MODULE
; Bytecode virtual machine
; ════════════════════════════════════════════════════════════════════════════

vm_run:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    
    call vga_newline
    mov esi, msg_vm_running
    mov ah, 0x0D
    call vga_print_line
    
    ; Initialize VM
    mov esi, 0x20000        ; Bytecode pointer
    mov ebp, 0x25000        ; Stack pointer
    
    ; Check magic
    cmp dword [esi], 0x4D53414D  ; "MASM"
    jne .vm_error
    
    ; Skip header
    add esi, 0x40
    
.vm_loop:
    movzx eax, byte [esi]
    inc esi
    
    ; Dispatch opcodes
    cmp al, 0x01            ; HALT
    je .vm_done
    cmp al, 0x17            ; CONST_SMALL
    je .op_const_small
    cmp al, 0x30            ; ADD
    je .op_add
    cmp al, 0x31            ; SUB
    je .op_sub
    cmp al, 0x32            ; MUL
    je .op_mul
    cmp al, 0x33            ; DIV
    je .op_div
    cmp al, 0x68            ; RET
    je .vm_done
    cmp al, 0xC3            ; PRINT
    je .op_print
    
    jmp .vm_loop

.op_const_small:
    movzx eax, byte [esi]
    inc esi
    sub ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_add:
    mov eax, [ebp]
    add ebp, 4
    add [ebp], eax
    jmp .vm_loop

.op_sub:
    mov eax, [ebp]
    add ebp, 4
    sub [ebp], eax
    jmp .vm_loop

.op_mul:
    mov eax, [ebp]
    add ebp, 4
    imul eax, [ebp]
    mov [ebp], eax
    jmp .vm_loop

.op_div:
    mov eax, [ebp+4]
    xor edx, edx
    idiv dword [ebp]
    add ebp, 4
    mov [ebp], eax
    jmp .vm_loop

.op_print:
    ; Print top of stack
    mov eax, [ebp]
    mov [vm_result], eax
    jmp .vm_loop

.vm_done:
    ; Show result
    call vga_newline
    mov esi, msg_vm_done
    mov ah, 0x0A
    call vga_print_line
    
    ; Display result number
    call vga_newline
    mov esi, msg_result
    mov ah, 0x0E
    call vga_print_line
    
    ; Convert result to string and display
    mov eax, [ebp]          ; Get top of stack
    call print_number
    
    jmp .vm_exit

.vm_error:
    call vga_newline
    mov esi, msg_vm_error
    mov ah, 0x0C
    call vga_print_line

.vm_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Print number in EAX to screen
print_number:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add ebx, 16             ; After "Result: "
    mov edi, ebx
    
    ; Convert to decimal
    mov ecx, 0
    mov ebx, 10
.div_loop:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .div_loop
    
.print_loop:
    pop eax
    add al, '0'
    mov ah, 0x0F
    stosw
    loop .print_loop
    
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

vm_result: dd 0
