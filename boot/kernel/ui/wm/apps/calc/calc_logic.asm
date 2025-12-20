; ============================================================================
; CALC_LOGIC.ASM - Calculator computation logic
; ============================================================================

[BITS 64]

; ============================================================================
; WMC_INPUT_DIGIT - Add digit to current input
; Input: EDI = ASCII digit ('0'-'9')
; ============================================================================
wmc_input_digit:
    push rbx
    push r12

    mov r12d, edi
    sub r12d, '0'                   ; Convert to number

    ; If new input, clear display
    cmp byte [calc_new_input], 1
    jne .append
    mov qword [calc_value2], 0
    mov byte [calc_new_input], 0

.append:
    ; value2 = value2 * 10 + digit
    mov rax, [calc_value2]
    imul rax, 10
    movzx rbx, r12b
    add rax, rbx
    mov [calc_value2], rax

    ; Update display
    call wmc_update_display

    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_SET_OPERATOR - Set operator and save current value
; Input: EDI = operator (CALC_OP_*)
; ============================================================================
wmc_set_operator:
    ; If we have pending operation, calculate first
    cmp byte [calc_operator], CALC_OP_NONE
    je .set_new
    push rdi
    call wmc_calculate
    pop rdi

.set_new:
    mov [calc_operator], dil
    mov rax, [calc_value2]
    mov [calc_value1], rax
    mov byte [calc_new_input], 1
    ret

; ============================================================================
; WMC_CALCULATE - Perform calculation
; ============================================================================
wmc_calculate:
    push rbx
    push r12

    mov rax, [calc_value1]
    mov rbx, [calc_value2]
    movzx ecx, byte [calc_operator]

    cmp ecx, CALC_OP_ADD
    je .do_add
    cmp ecx, CALC_OP_SUB
    je .do_sub
    cmp ecx, CALC_OP_MUL
    je .do_mul
    cmp ecx, CALC_OP_DIV
    je .do_div
    jmp .done                       ; No operator

.do_add:
    add rax, rbx
    jmp .store
.do_sub:
    sub rax, rbx
    jmp .store
.do_mul:
    imul rax, rbx
    jmp .store
.do_div:
    test rbx, rbx
    jz .done                        ; Divide by zero
    cqo
    idiv rbx

.store:
    mov [calc_value2], rax
    mov byte [calc_operator], CALC_OP_NONE
    mov byte [calc_new_input], 1
    call wmc_update_display

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_UPDATE_DISPLAY - Convert value2 to display string
; ============================================================================
wmc_update_display:
    push rbx
    push r12

    mov rax, [calc_value2]
    lea rdi, [calc_display + 15]    ; End of buffer
    mov byte [rdi], 0               ; Null terminate
    dec rdi

    ; Handle negative
    mov r12d, 0                     ; Sign flag
    test rax, rax
    jns .positive
    neg rax
    mov r12d, 1
.positive:

    ; Handle zero
    test rax, rax
    jnz .convert
    mov byte [rdi], '0'
    dec rdi
    jmp .add_sign

.convert:
    mov rbx, 10
.digit_loop:
    test rax, rax
    jz .add_sign
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    jmp .digit_loop

.add_sign:
    test r12d, r12d
    jz .copy
    mov byte [rdi], '-'
    dec rdi

.copy:
    ; Copy to start of buffer
    inc rdi
    lea rsi, [calc_display]
.copy_loop:
    mov al, [rdi]
    mov [rsi], al
    test al, al
    jz .done
    inc rdi
    inc rsi
    jmp .copy_loop

.done:
    pop r12
    pop rbx
    ret
