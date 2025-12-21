; ============================================================================
; CALC_MOD.ASM - Calculator Application Entry Point
; ============================================================================
; Main calculator window creation and management
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CALC_WIDTH              equ 230
CALC_HEIGHT             equ 320
WIN_DRAW_CB             equ 32
WIN_INPUT_CB            equ 40
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_TYPE_CALC           equ 1
CALC_BTN_W              equ 50
CALC_BTN_H              equ 40
CALC_BTN_GAP            equ 5
CALC_DISPLAY_H          equ 50
TITLE_HEIGHT            equ 24

; ============================================================================
; EXPORTS
; ============================================================================
global calc_open
global calc_window_draw
global calc_window_input

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_create_window
extern calc_draw
extern calc_clear
extern calc_on_digit
extern calc_on_operator
extern calc_on_equals
extern calc_on_clear

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; calc_open - Open calculator window
; Output: RAX = window pointer
; ----------------------------------------------------------------------------
calc_open:
    push rbx

    ; Initialize calculator state
    call calc_clear

    ; Create window
    mov edi, WIN_TYPE_CALC          ; type
    mov esi, 100                    ; x
    mov edx, 100                    ; y
    mov ecx, CALC_WIDTH             ; width
    mov r8d, CALC_HEIGHT            ; height
    lea r9, [str_calc_title]        ; title
    call wm_create_window

    test rax, rax
    jz .done

    ; Set callbacks
    mov rbx, rax
    lea rcx, [calc_window_draw]
    mov [rbx + WIN_DRAW_CB], rcx
    lea rcx, [calc_window_input]
    mov [rbx + WIN_INPUT_CB], rcx

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; calc_window_draw - Draw callback for calculator window
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
calc_window_draw:
    call calc_draw
    ret

; ----------------------------------------------------------------------------
; calc_window_input - Input callback for calculator window
; Input: RDI = window, ESI = x, EDX = y
; ----------------------------------------------------------------------------
calc_window_input:
    push rbx
    push r12
    push r13
    mov rbx, rdi

    ; Convert to window-relative coordinates
    mov r12d, esi
    sub r12d, [rbx + WIN_X]
    sub r12d, CALC_BTN_GAP
    mov r13d, edx
    sub r13d, [rbx + WIN_Y]
    sub r13d, TITLE_HEIGHT
    sub r13d, CALC_DISPLAY_H
    sub r13d, CALC_BTN_GAP * 2

    ; Check if click is in button area
    cmp r12d, 0
    jl .done
    cmp r13d, 0
    jl .done

    ; Calculate row (0-4)
    mov eax, r13d
    xor edx, edx
    mov ecx, CALC_BTN_H + CALC_BTN_GAP
    div ecx
    cmp eax, 5
    jge .done
    mov r13d, eax               ; r13 = row

    ; Calculate column (0-3)
    mov eax, r12d
    xor edx, edx
    mov ecx, CALC_BTN_W + CALC_BTN_GAP
    div ecx
    cmp eax, 4
    jge .done
    mov r12d, eax               ; r12 = col

    ; Dispatch based on row/col
    ; Row 0: C ( ) /
    cmp r13d, 0
    jne .row1
    cmp r12d, 0
    je .clear
    cmp r12d, 3
    je .op_div
    jmp .done

.row1:
    ; Row 1: 7 8 9 *
    cmp r13d, 1
    jne .row2
    cmp r12d, 3
    je .op_mul
    mov edi, r12d
    add edi, 7                  ; 7, 8, 9
    call calc_on_digit
    jmp .done

.row2:
    ; Row 2: 4 5 6 -
    cmp r13d, 2
    jne .row3
    cmp r12d, 3
    je .op_sub
    mov edi, r12d
    add edi, 4                  ; 4, 5, 6
    call calc_on_digit
    jmp .done

.row3:
    ; Row 3: 1 2 3 +
    cmp r13d, 3
    jne .row4
    cmp r12d, 3
    je .op_add
    mov edi, r12d
    add edi, 1                  ; 1, 2, 3
    call calc_on_digit
    jmp .done

.row4:
    ; Row 4: 0 0 . =
    cmp r13d, 4
    jne .done
    cmp r12d, 2
    jl .digit_0
    cmp r12d, 3
    je .equals
    jmp .done                   ; dot (not implemented)

.digit_0:
    xor edi, edi
    call calc_on_digit
    jmp .done

.clear:
    call calc_on_clear
    jmp .done

.op_add:
    mov edi, '+'
    call calc_on_operator
    jmp .done

.op_sub:
    mov edi, '-'
    call calc_on_operator
    jmp .done

.op_mul:
    mov edi, '*'
    call calc_on_operator
    jmp .done

.op_div:
    mov edi, '/'
    call calc_on_operator
    jmp .done

.equals:
    call calc_on_equals

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_calc_title:         db "Calculator", 0
