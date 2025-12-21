; ============================================================================
; DESKTOP_BG_MOD.ASM - Desktop Background
; ============================================================================
; Renders desktop background with gradient
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
DESKTOP_COLOR_TOP       equ 0x003366AA
DESKTOP_COLOR_BOT       equ 0x001A3355

; ============================================================================
; EXPORTS
; ============================================================================
global desktop_draw_background

; ============================================================================
; IMPORTS
; ============================================================================
extern screen_fb
extern screen_width
extern screen_height
extern screen_pitch

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; desktop_draw_background - Draw desktop gradient
; ----------------------------------------------------------------------------
desktop_draw_background:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, [screen_fb]
    test rbx, rbx
    jz .done

    mov r12d, [screen_width]
    mov r13d, [screen_height]
    mov r14d, [screen_pitch]

    ; Simple solid color for now (gradient later)
    xor r15d, r15d              ; y = 0

.row_loop:
    cmp r15d, r13d
    jge .done

    ; Calculate row address
    mov eax, r15d
    imul eax, r14d
    lea rdi, [rbx + rax]

    ; Fill row with color
    mov ecx, r12d
    mov eax, DESKTOP_COLOR_TOP

.col_loop:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .col_loop

    inc r15d
    jmp .row_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
