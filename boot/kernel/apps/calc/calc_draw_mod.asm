; ============================================================================
; CALC_DRAW_MOD.ASM - Calculator Drawing
; ============================================================================
; Render calculator UI with button labels
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CALC_BTN_W              equ 50
CALC_BTN_H              equ 40
CALC_BTN_GAP            equ 5
CALC_DISPLAY_H          equ 50
CALC_COLOR_BG           equ 0x00303030
CALC_COLOR_DISPLAY      equ 0x00202020
CALC_COLOR_BTN          equ 0x00505050
CALC_COLOR_BTN_OP       equ 0x00FF9500
CALC_COLOR_TEXT         equ 0x00FFFFFF

; ============================================================================
; EXPORTS
; ============================================================================
global calc_draw

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect
extern text_draw_string_xy
extern calc_display

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; calc_draw - Draw calculator in window
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
calc_draw:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi

    ; Get client area position
    mov r12d, [rbx + 8]             ; WIN_X
    mov r13d, [rbx + 12]            ; WIN_Y
    add r13d, 24                    ; Skip title bar

    ; Draw display background
    mov edi, r12d
    add edi, CALC_BTN_GAP
    mov esi, r13d
    add esi, CALC_BTN_GAP
    mov edx, CALC_BTN_W * 4 + CALC_BTN_GAP * 3
    mov ecx, CALC_DISPLAY_H
    mov r8d, CALC_COLOR_DISPLAY
    call draw_fill_rect

    ; Draw display text
    mov edi, r12d
    add edi, CALC_BTN_GAP + 10
    mov esi, r13d
    add esi, CALC_BTN_GAP + 15
    lea rdx, [calc_display]
    mov ecx, CALC_COLOR_TEXT
    call text_draw_string_xy

    ; Setup for button grid
    ; r14 = current row Y
    ; r15 = base X
    mov r14d, r13d
    add r14d, CALC_DISPLAY_H + CALC_BTN_GAP * 2
    mov r15d, r12d
    add r15d, CALC_BTN_GAP

    ; Row 1: C ( ) /
    mov edi, r15d
    mov esi, r14d
    mov r8d, CALC_COLOR_BTN
    lea r9, [str_C]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_lparen]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_rparen]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    mov r8d, CALC_COLOR_BTN_OP
    lea r9, [str_div]
    call .draw_labeled_btn

    ; Row 2: 7 8 9 *
    add r14d, CALC_BTN_H + CALC_BTN_GAP
    mov edi, r15d
    mov esi, r14d
    mov r8d, CALC_COLOR_BTN
    lea r9, [str_7]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_8]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_9]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    mov r8d, CALC_COLOR_BTN_OP
    lea r9, [str_mul]
    call .draw_labeled_btn

    ; Row 3: 4 5 6 -
    add r14d, CALC_BTN_H + CALC_BTN_GAP
    mov edi, r15d
    mov esi, r14d
    mov r8d, CALC_COLOR_BTN
    lea r9, [str_4]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_5]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_6]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    mov r8d, CALC_COLOR_BTN_OP
    lea r9, [str_minus]
    call .draw_labeled_btn

    ; Row 4: 1 2 3 +
    add r14d, CALC_BTN_H + CALC_BTN_GAP
    mov edi, r15d
    mov esi, r14d
    mov r8d, CALC_COLOR_BTN
    lea r9, [str_1]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_2]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    lea r9, [str_3]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    mov r8d, CALC_COLOR_BTN_OP
    lea r9, [str_plus]
    call .draw_labeled_btn

    ; Row 5: 0 . =
    add r14d, CALC_BTN_H + CALC_BTN_GAP
    mov edi, r15d
    mov esi, r14d
    mov r8d, CALC_COLOR_BTN
    ; 0 button (double width)
    push rdi
    push rsi
    mov edx, CALC_BTN_W * 2 + CALC_BTN_GAP
    mov ecx, CALC_BTN_H
    call draw_fill_rect
    pop rsi
    pop rdi
    push rdi
    push rsi
    add edi, 25
    add esi, 12
    mov rdx, r9
    lea rdx, [str_0]
    mov ecx, CALC_COLOR_TEXT
    call text_draw_string_xy
    pop rsi
    pop rdi
    add edi, CALC_BTN_W * 2 + CALC_BTN_GAP * 2
    lea r9, [str_dot]
    call .draw_labeled_btn
    add edi, CALC_BTN_W + CALC_BTN_GAP
    mov r8d, CALC_COLOR_BTN_OP
    lea r9, [str_eq]
    call .draw_labeled_btn

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Draw button with label
; Input: EDI=x, ESI=y, R8D=color, R9=label string
.draw_labeled_btn:
    push rdi
    push rsi
    push r9
    ; Draw button background
    mov edx, CALC_BTN_W
    mov ecx, CALC_BTN_H
    call draw_fill_rect
    pop r9
    pop rsi
    pop rdi
    ; Draw label centered
    push rdi
    push rsi
    add edi, 20                     ; Center text
    add esi, 12
    mov rdx, r9
    mov ecx, CALC_COLOR_TEXT
    call text_draw_string_xy
    pop rsi
    pop rdi
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_0:      db "0", 0
str_1:      db "1", 0
str_2:      db "2", 0
str_3:      db "3", 0
str_4:      db "4", 0
str_5:      db "5", 0
str_6:      db "6", 0
str_7:      db "7", 0
str_8:      db "8", 0
str_9:      db "9", 0
str_plus:   db "+", 0
str_minus:  db "-", 0
str_mul:    db "*", 0
str_div:    db "/", 0
str_eq:     db "=", 0
str_dot:    db ".", 0
str_C:      db "C", 0
str_lparen: db "(", 0
str_rparen: db ")", 0
