; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - MATH MODULE
; Arithmetic operations - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

vm_op_const_small:
    movzx eax, byte [esi]
    inc esi
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_const_int:
    mov eax, [esi]
    add esi, 4
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_add:
    mov eax, [ebp]
    add ebp, 4
    add [ebp], eax
    jmp vm_loop

vm_op_sub:
    mov eax, [ebp]
    add ebp, 4
    sub [ebp], eax
    jmp vm_loop

vm_op_mul:
    mov eax, [ebp]
    add ebp, 4
    imul eax, [ebp]
    mov [ebp], eax
    jmp vm_loop

vm_op_div:
    mov ebx, [ebp]
    add ebp, 4
    mov eax, [ebp]
    xor edx, edx
    test ebx, ebx
    jz vm_div_zero
    idiv ebx
    mov [ebp], eax
    jmp vm_loop
vm_div_zero:
    mov dword [ebp], 0
    jmp vm_loop

vm_op_mod:
    mov ebx, [ebp]
    add ebp, 4
    mov eax, [ebp]
    xor edx, edx
    test ebx, ebx
    jz vm_mod_zero
    idiv ebx
    mov [ebp], edx
    jmp vm_loop
vm_mod_zero:
    mov dword [ebp], 0
    jmp vm_loop

vm_op_neg:
    neg dword [ebp]
    jmp vm_loop
