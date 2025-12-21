; ============================================================================
; TERM_MOD.ASM - Terminal Application
; ============================================================================
; Command-line terminal window
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
TERM_WIDTH              equ 500
TERM_HEIGHT             equ 300
WIN_DRAW_CB             equ 32
WIN_TYPE_TERM           equ 5
TERM_COLOR_BG           equ 0x00000000
TERM_COLOR_TEXT         equ 0x0000FF00
TERM_MAX_LINES          equ 20
TERM_MAX_COLS           equ 60
TERM_LINE_HEIGHT        equ 12

; ============================================================================
; EXPORTS
; ============================================================================
global term_open
global term_draw
global term_print

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_create_window
extern draw_fill_rect
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; term_open - Open terminal window
; Output: RAX = window pointer
; ----------------------------------------------------------------------------
term_open:
    push rbx

    ; Clear terminal buffer
    call term_clear

    ; Print welcome message
    lea rdi, [str_welcome]
    call term_print

    ; Create window
    mov edi, WIN_TYPE_TERM
    mov esi, 100
    mov edx, 150
    mov ecx, TERM_WIDTH
    mov r8d, TERM_HEIGHT
    lea r9, [str_term_title]
    call wm_create_window

    test rax, rax
    jz .done

    mov rbx, rax
    lea rcx, [term_draw]
    mov [rbx + WIN_DRAW_CB], rcx

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; term_clear - Clear terminal buffer
; ----------------------------------------------------------------------------
term_clear:
    lea rdi, [term_buffer]
    xor al, al
    mov ecx, TERM_MAX_LINES * TERM_MAX_COLS
    rep stosb
    mov dword [term_line], 0
    ret

; ----------------------------------------------------------------------------
; term_print - Print string to terminal
; Input: RDI = string pointer
; ----------------------------------------------------------------------------
term_print:
    push rbx
    push r12

    mov r12, rdi
    mov eax, [term_line]
    cmp eax, TERM_MAX_LINES
    jge .scroll

    ; Calculate destination
    imul eax, TERM_MAX_COLS
    lea rbx, [term_buffer + rax]

    ; Copy string
.copy:
    mov al, [r12]
    test al, al
    jz .done_copy
    mov [rbx], al
    inc r12
    inc rbx
    jmp .copy

.done_copy:
    mov byte [rbx], 0
    inc dword [term_line]
    jmp .done

.scroll:
    ; Simple scroll: just reset
    call term_clear

.done:
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; term_draw - Draw terminal content
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
term_draw:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi

    ; Get client area
    mov r12d, [rbx + 8]
    mov r13d, [rbx + 12]
    add r13d, 24

    ; Draw black background
    mov edi, r12d
    mov esi, r13d
    mov edx, TERM_WIDTH
    mov ecx, TERM_HEIGHT - 24
    mov r8d, TERM_COLOR_BG
    call draw_fill_rect

    ; Draw lines
    xor r14d, r14d
    mov esi, r13d
    add esi, 5

.draw_loop:
    cmp r14d, [term_line]
    jge .done

    ; Calculate line buffer offset
    mov eax, r14d
    imul eax, TERM_MAX_COLS
    lea rdx, [term_buffer + rax]

    mov edi, r12d
    add edi, 5
    mov ecx, TERM_COLOR_TEXT
    push rsi
    call text_draw_string_xy
    pop rsi

    add esi, TERM_LINE_HEIGHT
    inc r14d
    jmp .draw_loop

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_term_title:         db "Terminal", 0
str_welcome:            db "MathisOS Terminal v1.0", 0

section .data

term_line:              dd 0

section .bss

term_buffer:            resb TERM_MAX_LINES * TERM_MAX_COLS
