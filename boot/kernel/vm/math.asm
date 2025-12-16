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

; ════════════════════════════════════════════════════════════════════════════
; LOGICAL OPERATIONS
; ════════════════════════════════════════════════════════════════════════════

vm_op_and:
    ; Logical AND: (a b -- a&&b)
    mov eax, [ebp]
    add ebp, 4
    test eax, eax
    jz .and_false
    test dword [ebp], 0xFFFFFFFF
    jz .and_false
    mov dword [ebp], 1
    jmp vm_loop
.and_false:
    mov dword [ebp], 0
    jmp vm_loop

vm_op_or:
    ; Logical OR: (a b -- a||b)
    mov eax, [ebp]
    add ebp, 4
    test eax, eax
    jnz .or_true
    test dword [ebp], 0xFFFFFFFF
    jnz .or_true
    mov dword [ebp], 0
    jmp vm_loop
.or_true:
    mov dword [ebp], 1
    jmp vm_loop

vm_op_xor:
    ; Logical XOR: (a b -- a^b)
    mov eax, [ebp]
    add ebp, 4
    test eax, eax
    setnz al
    test dword [ebp], 0xFFFFFFFF
    setnz cl
    xor al, cl
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_not:
    ; Logical NOT: (a -- !a)
    test dword [ebp], 0xFFFFFFFF
    setz al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; COMPARISON OPERATIONS
; ════════════════════════════════════════════════════════════════════════════

vm_op_eq:
    ; Equal: (a b -- a==b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    sete al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_ne:
    ; Not equal: (a b -- a!=b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    setne al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_lt:
    ; Less than: (a b -- a<b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    setl al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_gt:
    ; Greater than: (a b -- a>b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    setg al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_le:
    ; Less or equal: (a b -- a<=b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    setle al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop

vm_op_ge:
    ; Greater or equal: (a b -- a>=b)
    mov eax, [ebp]
    add ebp, 4
    cmp [ebp], eax
    setge al
    movzx eax, al
    mov [ebp], eax
    jmp vm_loop
