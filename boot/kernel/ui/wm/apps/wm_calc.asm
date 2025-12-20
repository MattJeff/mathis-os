; ============================================================================
; WM_CALC.ASM - Calculator application for window manager
; ============================================================================
; Single Responsibility: Calculator state and window creation
; ============================================================================

[BITS 64]

; Calculator dimensions
CALC_WIN_W          equ 240
CALC_WIN_H          equ 360
CALC_BTN_SIZE       equ 48
CALC_BTN_GAP        equ 4
CALC_DISPLAY_H      equ 50
CALC_MARGIN         equ 8

; Calculator colors
CALC_BG             equ 0x00202020
CALC_DISPLAY_BG     equ 0x00303030
CALC_DISPLAY_FG     equ 0x00FFFFFF
CALC_BTN_NUM        equ 0x00505050
CALC_BTN_OP         equ 0x00FF9500
CALC_BTN_FUNC       equ 0x00404040
CALC_BTN_TEXT       equ 0x00FFFFFF

; Operator constants
CALC_OP_NONE        equ 0
CALC_OP_ADD         equ 1
CALC_OP_SUB         equ 2
CALC_OP_MUL         equ 3
CALC_OP_DIV         equ 4

; Calculator state
calc_value1:        dq 0            ; First operand
calc_value2:        dq 0            ; Second operand (current input)
calc_operator:      db 0            ; Current operator
calc_new_input:     db 1            ; Start new number on next digit
calc_display:       times 16 db 0   ; Display buffer
calc_win_idx:       dd -1           ; Window index

; ============================================================================
; WMC_OPEN - Open calculator window
; Output: EAX = window index or -1
; ============================================================================
wmc_open:
    push rbx

    ; Check if already open
    cmp dword [calc_win_idx], -1
    jne .already_open

    ; Reset state
    call wmc_reset

    ; Create window
    mov edi, WM_TYPE_CALC
    mov esi, 300                    ; x
    mov edx, 100                    ; y
    mov ecx, CALC_WIN_W             ; width
    mov r8d, CALC_WIN_H             ; height
    lea r9, [calc_title]
    call wm_create_window
    cmp eax, -1
    je .done

    mov [calc_win_idx], eax
    mov byte [wm_dirty], 1
    jmp .done

.already_open:
    mov eax, [calc_win_idx]

.done:
    pop rbx
    ret

; ============================================================================
; WMC_RESET - Reset calculator state
; ============================================================================
wmc_reset:
    mov qword [calc_value1], 0
    mov qword [calc_value2], 0
    mov byte [calc_operator], CALC_OP_NONE
    mov byte [calc_new_input], 1
    lea rdi, [calc_display]
    mov byte [rdi], '0'
    mov byte [rdi+1], 0
    ret

; ============================================================================
; WMC_CLOSE - Close calculator (called by WM)
; ============================================================================
wmc_close:
    mov dword [calc_win_idx], -1
    ret

calc_title: db "Calculator", 0

; Include sub-modules
%include "ui/wm/apps/calc/calc_draw.asm"
%include "ui/wm/apps/calc/calc_input.asm"
%include "ui/wm/apps/calc/calc_logic.asm"
