; ============================================================================
; MathisOS - File Manager Main
; ============================================================================
; Entry point pour le mode FILES (mode 4)
; Orchestre les sous-modules: draw, view, nav, ops
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; FILES MODE - Entry point
; ════════════════════════════════════════════════════════════════════════════
files_mode:
    ; Only redraw if dirty flag is set
    cmp byte [files_dirty], 0
    je .files_skip_draw
    mov byte [files_dirty], 0        ; Clear dirty flag

    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Check if viewing a file
    cmp byte [files_viewing], 0
    jne .files_view_mode

    ; === FILE LIST MODE ===
    call files_draw_list
    jmp .files_done

.files_view_mode:
    ; === FILE VIEW MODE ===
    call files_draw_viewer

.files_done:
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

.files_skip_draw:
    ; Small delay to reduce CPU usage
    mov ecx, 50000
.files_delay:
    pause
    dec ecx
    jnz .files_delay
    jmp main_loop

; Include sub-modules
%include "modes/files/files_data.asm"
%include "modes/files/files_draw.asm"
%include "modes/files/files_view.asm"
