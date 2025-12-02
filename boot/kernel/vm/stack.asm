; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - STACK MODULE
; Stack manipulation - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

vm_op_dup:
    mov eax, [ebp]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_pop:
    add ebp, 4
    jmp vm_loop

vm_op_swap:
    mov eax, [ebp]
    mov ebx, [ebp+4]
    mov [ebp], ebx
    mov [ebp+4], eax
    jmp vm_loop

vm_op_over:
    mov eax, [ebp+4]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_rot:
    mov eax, [ebp]
    mov ebx, [ebp+4]
    mov ecx, [ebp+8]
    mov [ebp], ecx
    mov [ebp+4], eax
    mov [ebp+8], ebx
    jmp vm_loop
