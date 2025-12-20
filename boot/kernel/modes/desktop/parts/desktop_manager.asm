; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_MANAGER.ASM - Desktop manager (init + draw + input)
; ════════════════════════════════════════════════════════════════════════════
; Simple version without complex widget system
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_INIT - Simple initialization (no widgets)
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_init:
    cmp byte [desktop_initialized], 1
    je .done
    mov byte [desktop_initialized], 1
    mov byte [desktop_menu_open], 0
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_DRAW - Draw desktop without widget system
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_draw:
    ; 1. Background
    call desktop_draw_bg

    ; 2. Icons
    call desktop_draw_icons

    ; 3. Taskbar
    call desktop_draw_taskbar

    ret

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE_INPUT - Handle input
; ════════════════════════════════════════════════════════════════════════════
desktop_simple_input:
    call desktop_handle_click
    ret
