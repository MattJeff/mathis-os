; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - BITWISE MODULE
; Bit manipulation - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

vm_op_shl:
    ; SHL: Shift left (a n -- a<<n)
    mov ecx, [ebp]
    add ebp, 4
    shl dword [ebp], cl
    jmp vm_loop

vm_op_shr:
    ; SHR: Shift right arithmetic (a n -- a>>n)
    mov ecx, [ebp]
    add ebp, 4
    sar dword [ebp], cl
    jmp vm_loop

vm_op_ushr:
    ; USHR: Shift right logical (a n -- a>>>n)
    mov ecx, [ebp]
    add ebp, 4
    shr dword [ebp], cl
    jmp vm_loop

vm_op_band:
    ; BAND: Bitwise AND (a b -- a&b)
    mov eax, [ebp]
    add ebp, 4
    and [ebp], eax
    jmp vm_loop

vm_op_bor:
    ; BOR: Bitwise OR (a b -- a|b)
    mov eax, [ebp]
    add ebp, 4
    or [ebp], eax
    jmp vm_loop

vm_op_bxor:
    ; BXOR: Bitwise XOR (a b -- a^b)
    mov eax, [ebp]
    add ebp, 4
    xor [ebp], eax
    jmp vm_loop

vm_op_bnot:
    ; BNOT: Bitwise NOT (a -- ~a)
    not dword [ebp]
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; BIT TEST/SET/CLEAR
; ════════════════════════════════════════════════════════════════════════════

vm_op_btest:
    ; BTEST: Test bit (a n -- (a>>n)&1)
    mov ecx, [ebp]
    add ebp, 4
    mov eax, [ebp]
    shr eax, cl
    and eax, 1
    mov [ebp], eax
    jmp vm_loop

vm_op_bset:
    ; BSET: Set bit (a n -- a|(1<<n))
    mov ecx, [ebp]
    add ebp, 4
    mov eax, 1
    shl eax, cl
    or [ebp], eax
    jmp vm_loop

vm_op_bclr:
    ; BCLR: Clear bit (a n -- a&~(1<<n))
    mov ecx, [ebp]
    add ebp, 4
    mov eax, 1
    shl eax, cl
    not eax
    and [ebp], eax
    jmp vm_loop

vm_op_btoggle:
    ; BTOGGLE: Toggle bit (a n -- a^(1<<n))
    mov ecx, [ebp]
    add ebp, 4
    mov eax, 1
    shl eax, cl
    xor [ebp], eax
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; BIT COUNTING
; ════════════════════════════════════════════════════════════════════════════

vm_op_popcnt:
    ; POPCNT: Count set bits (a -- count)
    mov eax, [ebp]
    xor ecx, ecx
.popcnt_loop:
    test eax, eax
    jz .popcnt_done
    mov ebx, eax
    and ebx, 1
    add ecx, ebx
    shr eax, 1
    jmp .popcnt_loop
.popcnt_done:
    mov [ebp], ecx
    jmp vm_loop

vm_op_clz:
    ; CLZ: Count leading zeros
    mov eax, [ebp]
    bsr ecx, eax
    jz .clz_zero
    mov eax, 31
    sub eax, ecx
    mov [ebp], eax
    jmp vm_loop
.clz_zero:
    mov dword [ebp], 32
    jmp vm_loop

vm_op_ctz:
    ; CTZ: Count trailing zeros
    mov eax, [ebp]
    bsf ecx, eax
    jz .ctz_zero
    mov [ebp], ecx
    jmp vm_loop
.ctz_zero:
    mov dword [ebp], 32
    jmp vm_loop
