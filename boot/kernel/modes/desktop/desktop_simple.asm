; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_SIMPLE.ASM - Simple desktop without complex widget system
; ════════════════════════════════════════════════════════════════════════════
; Modular structure for easy debugging:
;   - desktop_data.asm     : Constants and state
;   - desktop_bg.asm       : Background drawing
;   - desktop_taskbar.asm  : Taskbar drawing
;   - desktop_icons.asm    : Icon drawing
;   - desktop_click.asm    : Click handling
;   - desktop_manager.asm  : Main init/draw/input functions
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Include all parts
%include "modes/desktop/parts/desktop_data.asm"
%include "modes/desktop/parts/desktop_bg.asm"
%include "modes/desktop/parts/desktop_taskbar.asm"
%include "modes/desktop/parts/desktop_icons.asm"
%include "modes/desktop/parts/desktop_click.asm"
%include "modes/desktop/parts/desktop_manager.asm"
