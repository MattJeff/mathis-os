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
    ; ROT: (a b c -- b c a)
    mov eax, [ebp]
    mov ebx, [ebp+4]
    mov ecx, [ebp+8]
    mov [ebp], ecx
    mov [ebp+4], eax
    mov [ebp+8], ebx
    jmp vm_loop

vm_op_pick:
    ; PICK n: Copy nth item to top (0 = top)
    mov eax, [ebp]          ; n
    shl eax, 2              ; n * 4
    add eax, 4              ; skip the n itself
    mov ebx, [ebp + eax]    ; get item
    mov [ebp], ebx          ; replace n with item
    jmp vm_loop

vm_op_roll:
    ; ROLL n: Move nth item to top, shift others down
    mov ecx, [ebp]          ; n
    add ebp, 4              ; pop n
    test ecx, ecx
    jz vm_loop              ; roll 0 = nop

    mov eax, ecx
    shl eax, 2              ; n * 4
    mov ebx, [ebp + eax]    ; save nth item

.roll_shift:
    mov edx, [ebp + eax - 4]
    mov [ebp + eax], edx
    sub eax, 4
    jnz .roll_shift

    mov [ebp], ebx          ; put saved item on top
    jmp vm_loop

vm_op_depth:
    ; DEPTH: Push stack depth
    mov eax, VM_STACK
    sub eax, ebp
    shr eax, 2              ; divide by 4
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop
