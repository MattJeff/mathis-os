; ============================================================================
; CALC_STATE_MOD.ASM - Calculator State & Logic
; ============================================================================
; Calculator state variables and operations
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CALC_MAX_DIGITS         equ 16
CALC_OP_NONE            equ 0
CALC_OP_ADD             equ 1
CALC_OP_SUB             equ 2
CALC_OP_MUL             equ 3
CALC_OP_DIV             equ 4

; ============================================================================
; EXPORTS
; ============================================================================
global calc_display
global calc_value
global calc_stored
global calc_operator
global calc_new_input
global calc_clear
global calc_on_digit
global calc_on_operator
global calc_on_equals
global calc_on_clear

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; calc_clear / calc_on_clear - Reset calculator state
; ----------------------------------------------------------------------------
calc_on_clear:
calc_clear:
    mov qword [calc_value], 0
    mov qword [calc_stored], 0
    mov byte [calc_operator], CALC_OP_NONE
    mov byte [calc_new_input], 1
    mov byte [calc_display], '0'
    mov byte [calc_display + 1], 0
    ret

; ----------------------------------------------------------------------------
; calc_on_digit - Handle digit input
; Input: EDI = digit (0-9)
; ----------------------------------------------------------------------------
calc_on_digit:
    push rbx

    ; If new_input, clear display first
    cmp byte [calc_new_input], 0
    je .append
    mov byte [calc_display], 0
    mov byte [calc_new_input], 0

.append:
    ; Find end of display string
    lea rbx, [calc_display]
    xor ecx, ecx
.find_end:
    cmp byte [rbx + rcx], 0
    je .at_end
    inc ecx
    cmp ecx, CALC_MAX_DIGITS - 1
    jge .done                       ; Max digits reached
    jmp .find_end

.at_end:
    ; Append digit
    add edi, '0'
    mov [rbx + rcx], dil
    mov byte [rbx + rcx + 1], 0

    ; Update calc_value
    call .update_value

.done:
    pop rbx
    ret

.update_value:
    ; Parse display string to number
    push rbx
    push r12
    lea rbx, [calc_display]
    xor r12, r12                    ; result
.parse_loop:
    movzx eax, byte [rbx]
    test al, al
    jz .parse_done
    sub al, '0'
    imul r12, 10
    add r12, rax
    inc rbx
    jmp .parse_loop
.parse_done:
    mov [calc_value], r12
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; calc_on_operator - Handle operator input
; Input: EDI = operator char ('+', '-', '*', '/')
; ----------------------------------------------------------------------------
calc_on_operator:
    ; If there's a pending operation, execute it first
    cmp byte [calc_operator], CALC_OP_NONE
    je .no_pending
    push rdi
    call calc_on_equals
    pop rdi
.no_pending:
    ; Store current value
    mov rax, [calc_value]
    mov [calc_stored], rax

    ; Set operator
    cmp edi, '+'
    je .op_add
    cmp edi, '-'
    je .op_sub
    cmp edi, '*'
    je .op_mul
    cmp edi, '/'
    je .op_div
    ret

.op_add:
    mov byte [calc_operator], CALC_OP_ADD
    jmp .set_new
.op_sub:
    mov byte [calc_operator], CALC_OP_SUB
    jmp .set_new
.op_mul:
    mov byte [calc_operator], CALC_OP_MUL
    jmp .set_new
.op_div:
    mov byte [calc_operator], CALC_OP_DIV
.set_new:
    mov byte [calc_new_input], 1
    ret

; ----------------------------------------------------------------------------
; calc_on_equals - Execute pending operation
; ----------------------------------------------------------------------------
calc_on_equals:
    push rbx
    push r12

    movzx eax, byte [calc_operator]
    test al, al
    jz .done                        ; No operation pending

    mov rbx, [calc_stored]          ; First operand
    mov r12, [calc_value]           ; Second operand

    cmp al, CALC_OP_ADD
    je .do_add
    cmp al, CALC_OP_SUB
    je .do_sub
    cmp al, CALC_OP_MUL
    je .do_mul
    cmp al, CALC_OP_DIV
    je .do_div
    jmp .done

.do_add:
    add rbx, r12
    jmp .store_result
.do_sub:
    sub rbx, r12
    jmp .store_result
.do_mul:
    imul rbx, r12
    jmp .store_result
.do_div:
    test r12, r12
    jz .done                        ; Division by zero
    mov rax, rbx
    xor rdx, rdx
    div r12
    mov rbx, rax

.store_result:
    mov [calc_value], rbx
    mov byte [calc_operator], CALC_OP_NONE

    ; Convert result to display string
    call .value_to_display

.done:
    pop r12
    pop rbx
    ret

.value_to_display:
    push rbx
    push r12
    push r13

    mov rax, [calc_value]
    lea rbx, [calc_display + CALC_MAX_DIGITS]
    mov byte [rbx], 0               ; Null terminator
    dec rbx
    mov r12, 10
    xor r13d, r13d                  ; digit count

    test rax, rax
    jnz .convert_loop
    ; Value is 0
    mov byte [rbx], '0'
    dec rbx
    inc r13d
    jmp .move_string

.convert_loop:
    test rax, rax
    jz .move_string
    xor rdx, rdx
    div r12
    add dl, '0'
    mov [rbx], dl
    dec rbx
    inc r13d
    jmp .convert_loop

.move_string:
    ; Move string to start of buffer
    inc rbx
    lea rdi, [calc_display]
.copy_loop:
    mov al, [rbx]
    mov [rdi], al
    test al, al
    jz .conv_done
    inc rbx
    inc rdi
    jmp .copy_loop

.conv_done:
    mov byte [calc_new_input], 1
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

calc_value:             dq 0
calc_stored:            dq 0
calc_operator:          db CALC_OP_NONE
calc_new_input:         db 1

; ============================================================================
; BSS
; ============================================================================
section .bss

calc_display:           resb CALC_MAX_DIGITS + 1
