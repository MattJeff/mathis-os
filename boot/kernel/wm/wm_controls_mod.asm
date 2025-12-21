; ============================================================================
; WM_CONTROLS_MOD.ASM - Mac-style Window Controls
; ============================================================================
; Red (close), Orange (minimize), Green (maximize) buttons
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CTRL_BTN_SIZE           equ 12
CTRL_BTN_SPACING        equ 8
CTRL_BTN_MARGIN_X       equ 8
CTRL_BTN_MARGIN_Y       equ 6

CTRL_COLOR_CLOSE        equ 0x00FF5F57      ; Red
CTRL_COLOR_MINIMIZE     equ 0x00FFBD2E      ; Orange
CTRL_COLOR_MAXIMIZE     equ 0x0028CA41      ; Green
CTRL_COLOR_INACTIVE     equ 0x00505050      ; Gray when inactive

; ============================================================================
; EXPORTS
; ============================================================================
global wm_draw_controls
global wm_controls_hit_test

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; wm_draw_controls - Draw Mac-style window control buttons
; Input: EDI = window x, ESI = window y, EDX = active (1/0)
; ----------------------------------------------------------------------------
wm_draw_controls:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi                   ; window x
    mov r13d, esi                   ; window y
    mov r14d, edx                   ; active flag

    ; Calculate button Y position (centered in title bar)
    add r13d, CTRL_BTN_MARGIN_Y

    ; Draw close button (red)
    mov edi, r12d
    add edi, CTRL_BTN_MARGIN_X
    mov esi, r13d
    mov edx, CTRL_BTN_SIZE
    mov ecx, CTRL_BTN_SIZE
    mov r8d, CTRL_COLOR_CLOSE
    test r14d, r14d
    jnz .close_active
    mov r8d, CTRL_COLOR_INACTIVE
.close_active:
    call draw_fill_rect

    ; Draw minimize button (orange)
    mov edi, r12d
    add edi, CTRL_BTN_MARGIN_X + CTRL_BTN_SIZE + CTRL_BTN_SPACING
    mov esi, r13d
    mov edx, CTRL_BTN_SIZE
    mov ecx, CTRL_BTN_SIZE
    mov r8d, CTRL_COLOR_MINIMIZE
    test r14d, r14d
    jnz .min_active
    mov r8d, CTRL_COLOR_INACTIVE
.min_active:
    call draw_fill_rect

    ; Draw maximize button (green)
    mov edi, r12d
    add edi, CTRL_BTN_MARGIN_X + (CTRL_BTN_SIZE + CTRL_BTN_SPACING) * 2
    mov esi, r13d
    mov edx, CTRL_BTN_SIZE
    mov ecx, CTRL_BTN_SIZE
    mov r8d, CTRL_COLOR_MAXIMIZE
    test r14d, r14d
    jnz .max_active
    mov r8d, CTRL_COLOR_INACTIVE
.max_active:
    call draw_fill_rect

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_controls_hit_test - Test if click hits a control button
; Input: EDI = click x, ESI = click y, EDX = window x, ECX = window y
; Output: EAX = 0 (none), 1 (close), 2 (minimize), 3 (maximize)
; ----------------------------------------------------------------------------
wm_controls_hit_test:
    ; Calculate button Y range
    mov r8d, ecx
    add r8d, CTRL_BTN_MARGIN_Y
    mov r9d, r8d
    add r9d, CTRL_BTN_SIZE

    ; Check Y bounds
    cmp esi, r8d
    jl .no_hit
    cmp esi, r9d
    jg .no_hit

    ; Calculate relative X from window
    sub edi, edx
    sub edi, CTRL_BTN_MARGIN_X

    ; Check close button (0 to CTRL_BTN_SIZE)
    cmp edi, 0
    jl .no_hit
    cmp edi, CTRL_BTN_SIZE
    jl .hit_close

    ; Check minimize button
    sub edi, CTRL_BTN_SIZE + CTRL_BTN_SPACING
    cmp edi, 0
    jl .no_hit
    cmp edi, CTRL_BTN_SIZE
    jl .hit_minimize

    ; Check maximize button
    sub edi, CTRL_BTN_SIZE + CTRL_BTN_SPACING
    cmp edi, 0
    jl .no_hit
    cmp edi, CTRL_BTN_SIZE
    jl .hit_maximize

.no_hit:
    xor eax, eax
    ret
.hit_close:
    mov eax, 1
    ret
.hit_minimize:
    mov eax, 2
    ret
.hit_maximize:
    mov eax, 3
    ret
