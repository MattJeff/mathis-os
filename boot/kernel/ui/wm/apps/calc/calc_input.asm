; ============================================================================
; CALC_INPUT.ASM - Calculator input handling
; ============================================================================

[BITS 64]

; ============================================================================
; WMC_ON_KEY - Handle keyboard input
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wmc_on_key:
    push rbx
    mov ebx, edi

    ; Let ESC pass through for window close
    cmp ebx, 0x01
    je .not_handled

    ; Convert to ASCII
    mov esi, ebx
    call scancode_to_ascii
    test al, al
    jz .not_handled

    ; Handle digit 0-9
    cmp al, '0'
    jl .check_op
    cmp al, '9'
    jg .check_op
    movzx edi, al
    call wmc_input_digit
    jmp .handled

.check_op:
    ; Operators
    cmp al, '+'
    je .op_add
    cmp al, '-'
    je .op_sub
    cmp al, '*'
    je .op_mul
    cmp al, '/'
    je .op_div
    cmp al, '='
    je .do_equals
    cmp al, 13                      ; Enter = equals
    je .do_equals
    jmp .not_handled

.op_add:
    mov edi, CALC_OP_ADD
    jmp .set_op
.op_sub:
    mov edi, CALC_OP_SUB
    jmp .set_op
.op_mul:
    mov edi, CALC_OP_MUL
    jmp .set_op
.op_div:
    mov edi, CALC_OP_DIV
.set_op:
    call wmc_set_operator
    jmp .handled

.do_equals:
    call wmc_calculate
    jmp .handled

.handled:
    mov byte [wm_dirty], 1
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ============================================================================
; WMC_ON_CLICK - Handle mouse click
; Input: EDI = x (relative), ESI = y (relative)
; Output: EAX = 1
; ============================================================================
wmc_on_click:
    push rbx
    push r12
    push r13

    mov r12d, edi                   ; x relative to content
    mov r13d, esi                   ; y relative to content

    ; Check if in button area
    mov eax, CALC_DISPLAY_H
    add eax, CALC_MARGIN
    add eax, CALC_MARGIN
    cmp r13d, eax
    jl .done                        ; Click in display, ignore

    ; Calculate row
    sub r13d, eax
    mov eax, r13d
    xor edx, edx
    mov ecx, CALC_BTN_SIZE
    add ecx, CALC_BTN_GAP
    div ecx
    mov r13d, eax                   ; row (0-4)

    ; Calculate column
    mov eax, r12d
    sub eax, CALC_MARGIN
    xor edx, edx
    mov ecx, CALC_BTN_SIZE
    add ecx, CALC_BTN_GAP
    div ecx
    mov r12d, eax                   ; col (0-3)

    ; Dispatch based on row/col
    call wmc_handle_button

.done:
    mov byte [wm_dirty], 1
    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_HANDLE_BUTTON - Handle button press by row/col
; Input: R12D = col (0-3), R13D = row (0-4)
; ============================================================================
wmc_handle_button:
    ; Row 0: C, +/-, %, /
    cmp r13d, 0
    jne .row1
    cmp r12d, 0
    je .btn_clear
    cmp r12d, 3
    je .btn_div
    ret

.row1:  ; 7, 8, 9, *
    cmp r13d, 1
    jne .row2
    cmp r12d, 3
    je .btn_mul
    mov edi, r12d
    add edi, '7'
    jmp wmc_input_digit

.row2:  ; 4, 5, 6, -
    cmp r13d, 2
    jne .row3
    cmp r12d, 3
    je .btn_sub
    mov edi, r12d
    add edi, '4'
    jmp wmc_input_digit

.row3:  ; 1, 2, 3, +
    cmp r13d, 3
    jne .row4
    cmp r12d, 3
    je .btn_add
    mov edi, r12d
    add edi, '1'
    jmp wmc_input_digit

.row4:  ; 0, ., =
    cmp r13d, 4
    jne .done_btn
    cmp r12d, 2
    jl .btn_zero
    cmp r12d, 3
    je .btn_equals
    ret

.btn_clear:
    jmp wmc_reset
.btn_div:
    mov edi, CALC_OP_DIV
    jmp wmc_set_operator
.btn_mul:
    mov edi, CALC_OP_MUL
    jmp wmc_set_operator
.btn_sub:
    mov edi, CALC_OP_SUB
    jmp wmc_set_operator
.btn_add:
    mov edi, CALC_OP_ADD
    jmp wmc_set_operator
.btn_zero:
    mov edi, '0'
    jmp wmc_input_digit
.btn_equals:
    jmp wmc_calculate
.done_btn:
    ret
