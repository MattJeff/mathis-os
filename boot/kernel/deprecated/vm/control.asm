; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - CONTROL FLOW MODULE
; Jumps, calls, loops - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

; Call stack for return addresses (separate from data stack)
VM_CALL_STACK   equ 0x27000
VM_FRAME_PTR    equ 0x27FFC         ; Frame pointer storage

vm_op_jmp:
    ; JMP offset: Unconditional jump (signed 16-bit offset)
    movsx eax, word [esi]
    add esi, 2
    add esi, eax                    ; esi += offset
    jmp vm_loop

vm_op_jz:
    ; JZ offset: Jump if zero (pop and test)
    mov eax, [ebp]
    add ebp, 4                      ; pop
    movsx ebx, word [esi]
    add esi, 2
    test eax, eax
    jnz vm_loop                     ; not zero, continue
    add esi, ebx                    ; zero, jump
    jmp vm_loop

vm_op_jnz:
    ; JNZ offset: Jump if not zero
    mov eax, [ebp]
    add ebp, 4                      ; pop
    movsx ebx, word [esi]
    add esi, 2
    test eax, eax
    jz vm_loop                      ; zero, continue
    add esi, ebx                    ; not zero, jump
    jmp vm_loop

vm_op_call:
    ; CALL offset: Call subroutine
    ; Push return address to call stack
    mov eax, [vm_call_sp]
    sub eax, 4
    mov [vm_call_sp], eax

    ; Calculate return address (after the offset)
    lea ebx, [esi + 2]
    mov [eax], ebx                  ; save return address

    ; Jump to subroutine
    movsx eax, word [esi]
    add esi, 2
    add esi, eax
    jmp vm_loop

vm_op_ret:
    ; RET: Return from subroutine
    mov eax, [vm_call_sp]
    mov esi, [eax]                  ; restore instruction pointer
    add eax, 4
    mov [vm_call_sp], eax
    jmp vm_loop

vm_op_loop:
    ; LOOP: Decrement top, jump if not zero
    dec dword [ebp]
    jz .loop_done
    movsx eax, word [esi]
    add esi, eax                    ; jump back
    jmp vm_loop
.loop_done:
    add esi, 2                      ; skip offset
    add ebp, 4                      ; pop counter
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; CONDITIONAL JUMPS (additional)
; ════════════════════════════════════════════════════════════════════════════

vm_op_jlt:
    ; JLT offset: Jump if a < b
    mov eax, [ebp]
    mov ebx, [ebp + 4]
    add ebp, 8
    movsx ecx, word [esi]
    add esi, 2
    cmp ebx, eax
    jge vm_loop
    add esi, ecx
    jmp vm_loop

vm_op_jgt:
    ; JGT offset: Jump if a > b
    mov eax, [ebp]
    mov ebx, [ebp + 4]
    add ebp, 8
    movsx ecx, word [esi]
    add esi, 2
    cmp ebx, eax
    jle vm_loop
    add esi, ecx
    jmp vm_loop

vm_op_jeq:
    ; JEQ offset: Jump if a == b
    mov eax, [ebp]
    mov ebx, [ebp + 4]
    add ebp, 8
    movsx ecx, word [esi]
    add esi, 2
    cmp ebx, eax
    jne vm_loop
    add esi, ecx
    jmp vm_loop

vm_op_jne_cmp:
    ; JNE offset: Jump if a != b
    mov eax, [ebp]
    mov ebx, [ebp + 4]
    add ebp, 8
    movsx ecx, word [esi]
    add esi, 2
    cmp ebx, eax
    je vm_loop
    add esi, ecx
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
vm_call_sp:     dd VM_CALL_STACK    ; Call stack pointer
