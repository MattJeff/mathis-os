; ============================================================================
; MathisOS - File Manager Main (REFACTORED with Widgets)
; ============================================================================
; Entry point pour le mode FILES (mode 4)
; Now uses widget system for UI
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; FILES MODE - Entry point (called from main_loop)
; ════════════════════════════════════════════════════════════════════════════
files_mode:
    ; Initialize widgets on first call
    call files_app_init

    ; Only redraw if dirty flag is set
    cmp byte [files_dirty], 0
    je .skip_draw

    mov byte [files_dirty], 0       ; Clear dirty flag

    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Draw using widget system
    call files_app_draw

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

.skip_draw:
    ; Small delay to reduce CPU usage
    mov ecx, 50000
.delay:
    pause
    dec ecx
    jnz .delay

    jmp main_loop

; Include widget-based app controller
%include "modes/files/files_app.asm"

; Legacy data (still needed for some variables)
%include "modes/files/files_data.asm"

; Legacy draw functions (kept for reference, will be removed later)
; %include "modes/files/files_draw.asm"
; %include "modes/files/files_view.asm"
