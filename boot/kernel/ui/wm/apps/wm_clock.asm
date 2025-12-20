; ============================================================================
; WM_CLOCK.ASM - Clock application for window manager
; ============================================================================
; Single Responsibility: Clock state and window creation
; ============================================================================

[BITS 64]

; Clock dimensions
CLOCK_WIN_W         equ 200
CLOCK_WIN_H         equ 220

; Display modes
CLOCK_MODE_DIGITAL  equ 0
CLOCK_MODE_ANALOG   equ 1
CLOCK_MODE_COUNT    equ 2

; Colors
CLOCK_BG            equ 0x00202020
CLOCK_FG            equ 0x00FFFFFF
CLOCK_ACCENT        equ 0x00FF9500
CLOCK_HAND_H        equ 0x00FF5050      ; Hour hand (red)
CLOCK_HAND_M        equ 0x0050FF50      ; Minute hand (green)
CLOCK_HAND_S        equ 0x005050FF      ; Second hand (blue)

; Clock state
clock_mode:         db CLOCK_MODE_DIGITAL
clock_win_idx:      dd -1
clock_last_sec:     db 0xFF             ; Force first update

; ============================================================================
; WMCLK_OPEN - Open clock window
; Output: EAX = window index or -1
; ============================================================================
wmclk_open:
    push rbx

    ; Check if already open
    cmp dword [clock_win_idx], -1
    jne .already_open

    ; Create window
    mov edi, WM_TYPE_CLOCK
    mov esi, 400                    ; x
    mov edx, 80                     ; y
    mov ecx, CLOCK_WIN_W
    mov r8d, CLOCK_WIN_H
    lea r9, [clock_title]
    call wm_create_window
    cmp eax, -1
    je .done

    mov [clock_win_idx], eax
    mov byte [wm_dirty], 1
    jmp .done

.already_open:
    mov eax, [clock_win_idx]

.done:
    pop rbx
    ret

; ============================================================================
; WMCLK_CLOSE - Close clock (called by WM)
; ============================================================================
wmclk_close:
    mov dword [clock_win_idx], -1
    ret

; ============================================================================
; WMCLK_TOGGLE_MODE - Switch between digital and analog
; ============================================================================
wmclk_toggle_mode:
    inc byte [clock_mode]
    cmp byte [clock_mode], CLOCK_MODE_COUNT
    jl .done
    mov byte [clock_mode], 0
.done:
    mov byte [wm_dirty], 1
    ret

clock_title: db "Clock", 0

; Include sub-modules
%include "ui/wm/apps/clock/clock_draw.asm"
%include "ui/wm/apps/clock/clock_input.asm"
