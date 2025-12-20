; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR.ASM - Finder-style sidebar (main include)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

%include "widgets/sidebar/sidebar_data.asm"
%include "widgets/sidebar/sidebar_draw.asm"
%include "widgets/sidebar/sidebar_input.asm"

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_INIT - Initialize sidebar
; Input: EDI = x, ESI = y, EDX = height
; ════════════════════════════════════════════════════════════════════════════
sidebar_init:
    mov [sidebar_x], edi
    mov [sidebar_y], esi
    mov [sidebar_h], edx
    mov dword [sidebar_selected], 1
    mov dword [sidebar_hover], -1
    mov byte [sidebar_visible], 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_SET_CALLBACK - Set selection callback
; ════════════════════════════════════════════════════════════════════════════
sidebar_set_callback:
    mov [sidebar_on_select], rdi
    ret
