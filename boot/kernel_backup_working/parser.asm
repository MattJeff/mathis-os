; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - PARSER MODULE
; Parse MathisScript and compile to bytecode
; ════════════════════════════════════════════════════════════════════════════

compile_command:
    push eax
    push ebx
    push esi
    push edi
    
    ; Check if we have content
    cmp dword [file_content_len], 0
    je .no_content
    
    ; Show what we're compiling
    call vga_newline
    mov esi, msg_compiling
    mov ah, 0x0D
    call vga_print_line
    
    call vga_newline
    mov esi, file_content
    mov ah, 0x07
    call vga_print_line
    
    ; Parse expression
    call parse_expression
    
    ; Generate bytecode at 0x21000
    call generate_bytecode
    
    ; Success
    call vga_newline
    mov esi, msg_compiled
    mov ah, 0x0A
    call vga_print_line
    jmp .done

.no_content:
    call vga_newline
    mov esi, msg_no_content
    mov ah, 0x0C
    call vga_print_line

.done:
    pop edi
    pop esi
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; PARSE EXPRESSION - Extract NUM OP NUM from file_content
; ════════════════════════════════════════════════════════════════════════════
parse_expression:
    push eax
    push ebx
    push esi
    
    mov dword [parse_num1], 0
    mov dword [parse_num2], 0
    mov byte [parse_op], '+'
    
    mov esi, file_content
    
.find_num1:
    lodsb
    test al, al
    jz .parse_done
    cmp al, '0'
    jl .find_num1
    cmp al, '9'
    jg .find_num1
    
    ; Parse first number
    xor ebx, ebx
.parse_num1:
    sub al, '0'
    movzx eax, al
    imul ebx, 10
    add ebx, eax
    lodsb
    cmp al, '0'
    jl .num1_done
    cmp al, '9'
    jle .parse_num1
.num1_done:
    mov [parse_num1], ebx
    
.find_op:
    cmp al, '+'
    je .found_op
    cmp al, '-'
    je .found_op
    cmp al, '*'
    je .found_op
    cmp al, '/'
    je .found_op
    lodsb
    test al, al
    jz .parse_done
    jmp .find_op
.found_op:
    mov [parse_op], al
    
.find_num2:
    lodsb
    test al, al
    jz .parse_done
    cmp al, '0'
    jl .find_num2
    cmp al, '9'
    jg .find_num2
    
    xor ebx, ebx
.parse_num2:
    sub al, '0'
    movzx eax, al
    imul ebx, 10
    add ebx, eax
    lodsb
    cmp al, '0'
    jl .num2_done
    cmp al, '9'
    jle .parse_num2
.num2_done:
    mov [parse_num2], ebx

.parse_done:
    pop esi
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; GENERATE BYTECODE - Create .mbc at 0x21000
; ════════════════════════════════════════════════════════════════════════════
generate_bytecode:
    push eax
    push edi
    
    ; Write header
    mov edi, 0x21000
    mov dword [edi], 0x4D53414D     ; "MASM"
    mov dword [edi+4], 0x00000001   ; Version
    
    ; Pad header to 0x40
    add edi, 8
    mov ecx, 56
    xor eax, eax
    rep stosb
    
    ; Write bytecode at 0x21040
    mov edi, 0x21040
    
    ; CONST_SMALL num1
    mov byte [edi], 0x17
    mov eax, [parse_num1]
    mov [edi+1], al
    
    ; CONST_SMALL num2
    mov byte [edi+2], 0x17
    mov eax, [parse_num2]
    mov [edi+3], al
    
    ; Operator
    mov al, [parse_op]
    cmp al, '+'
    je .gen_add
    cmp al, '-'
    je .gen_sub
    cmp al, '*'
    je .gen_mul
    cmp al, '/'
    je .gen_div
    jmp .gen_add
.gen_add:
    mov byte [edi+4], 0x30
    jmp .gen_end
.gen_sub:
    mov byte [edi+4], 0x31
    jmp .gen_end
.gen_mul:
    mov byte [edi+4], 0x32
    jmp .gen_end
.gen_div:
    mov byte [edi+4], 0x33
.gen_end:
    mov byte [edi+5], 0x68          ; RET
    
    ; Copy to execution area
    mov esi, 0x21000
    mov edi, 0x20000
    mov ecx, 128
    rep movsb
    
    pop edi
    pop eax
    ret

; Parser state
parse_num1: dd 0
parse_num2: dd 0
parse_op:   db '+'
