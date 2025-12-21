; ============================================================================
; CLOCK_MOD.ASM - Clock Application
; ============================================================================
; Digital clock window
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CLOCK_WIDTH             equ 200
CLOCK_HEIGHT            equ 120
WIN_DRAW_CB             equ 32
WIN_TYPE_CLOCK          equ 2
CLOCK_COLOR_BG          equ 0x00202020
CLOCK_COLOR_TEXT        equ 0x0000FF00

; ============================================================================
; EXPORTS
; ============================================================================
global clock_open
global clock_draw

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_create_window
extern draw_fill_rect
extern text_draw_string_xy
extern rtc_get_time

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; clock_open - Open clock window
; Output: RAX = window pointer
; ----------------------------------------------------------------------------
clock_open:
    push rbx

    mov edi, WIN_TYPE_CLOCK
    mov esi, 400
    mov edx, 100
    mov ecx, CLOCK_WIDTH
    mov r8d, CLOCK_HEIGHT
    lea r9, [str_clock_title]
    call wm_create_window

    test rax, rax
    jz .done

    mov rbx, rax
    lea rcx, [clock_draw]
    mov [rbx + WIN_DRAW_CB], rcx

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; clock_draw - Draw clock window content
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
clock_draw:
    push rbx
    push r12
    push r13
    mov rbx, rdi

    ; Get client area
    mov r12d, [rbx + 8]             ; WIN_X
    mov r13d, [rbx + 12]            ; WIN_Y
    add r13d, 24                    ; Skip title

    ; Draw background
    mov edi, r12d
    mov esi, r13d
    mov edx, CLOCK_WIDTH
    mov ecx, CLOCK_HEIGHT - 24
    mov r8d, CLOCK_COLOR_BG
    call draw_fill_rect

    ; Get time (placeholder - uses static time)
    ; In real implementation, call rtc_get_time

    ; Draw time string
    mov edi, r12d
    add edi, 40
    mov esi, r13d
    add esi, 35
    lea rdx, [clock_time_str]
    mov ecx, CLOCK_COLOR_TEXT
    call text_draw_string_xy

    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_clock_title:        db "Clock", 0
clock_time_str:         db "12:34:56", 0
